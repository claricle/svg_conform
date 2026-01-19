# frozen_string_literal_literal: true

require_relative "profile"

module SvgConform
  module Profiles
    PROFILES_DIR = File.expand_path("../../config/profiles", __dir__)

    # Cache configuration
    MAX_CACHE_SIZE = 50  # Maximum number of profiles to cache
    ENABLE_CACHE = true   # Can be disabled for testing

    # Thread-safe cache with LRU eviction
    @cache = {}
    @cache_mutex = Mutex.new
    @access_order = []  # Track access order for LRU eviction

    # Cache statistics
    @cache_hits = 0
    @cache_misses = 0
    @cache_stats_mutex = Mutex.new

    class << self
      # Get a profile by ID or instance
      # @param profile_id [String, Symbol, Profile] profile identifier
      # @return [Profile] the profile
      def get(profile_id)
        case profile_id
        when Symbol, String
          load_profile(profile_id.to_s)
        when Profile
          profile_id
        else
          raise ProfileError, "Invalid profile: #{profile_id}"
        end
      end

      # Get list of available profile names
      # @return [Array<Symbol>] list of available profile names
      def available_profiles
        return @cache.keys.map(&:to_sym) if @cache.any?

        profile_files = Dir.glob(File.join(PROFILES_DIR, "*.yml"))
        profile_files.map { |file| File.basename(file, ".yml").to_sym }
      end

      # Load a profile by name
      # @param profile_name [String] profile name
      # @return [Profile] the loaded profile
      def load(profile_name)
        load_profile(profile_name.to_s)
      end

      # Get list of profile names as strings
      # @return [Array<String>] list of profile names
      def list
        available_profiles.map(&:to_s)
      end

      # Clear the profile cache
      # @return [void]
      def clear_cache!
        @cache_mutex.synchronize do
          @cache.clear
          @access_order.clear
        end

        # Reset cache statistics
        @cache_stats_mutex.synchronize do
          @cache_hits = 0
          @cache_misses = 0
        end
      end

      # Get cache statistics
      # @return [Hash] cache statistics
      def cache_stats
        @cache_stats_mutex.synchronize do
          {
            size: @cache.length,
            max_size: MAX_CACHE_SIZE,
            hits: @cache_hits,
            misses: @cache_misses,
            hit_ratio: total_cache_operations > 0 ? @cache_hits.to_f / total_cache_operations : 0.0,
            access_order: @access_order.dup,
          }
        end
      end

      # Check if caching is enabled
      # @return [Boolean] true if caching is enabled
      def cache_enabled?
        ENABLE_CACHE
      end

      # Preload profiles into cache (useful for batch operations)
      # @param profile_names [Array<String>] list of profile names to preload
      # @return [Hash] map of profile name to load status
      def preload(*profile_names)
        profile_names.flatten.each do |name|
          load_profile(name) rescue nil # Silently skip failures
        end
        {
          total_loaded: @cache.length,
          requested: profile_names.flatten.length,
        }
      end

      # Invalidate specific profile in cache
      # @param profile_name [String] profile name to invalidate
      # @return [Boolean] true if profile was in cache
      def invalidate(profile_name)
        @cache_mutex.synchronize do
          if @cache.key?(profile_name)
            @cache.delete(profile_name)
            @access_order.delete(profile_name)
            return true
          end
          false
        end
      end

      private

      # Load profile from file with caching
      # @param profile_name [String] profile name
      # @return [Profile] the loaded profile
      def load_profile(profile_name)
        # Check cache first if enabled
        if ENABLE_CACHE
          @cache_mutex.synchronize do
            if @cache[profile_name]
              # Update access order for LRU
              @access_order.delete(profile_name)
              @access_order.push(profile_name)

              # Record cache hit
              @cache_stats_mutex.synchronize { @cache_hits += 1 }

              return @cache[profile_name]
            end

            # Check if cache is full before loading
            evict_lru_if_full
          end
        end

        # Record cache miss
        @cache_stats_mutex.synchronize { @cache_misses += 1 } if ENABLE_CACHE

        # Load profile from file
        profile_file = File.join(PROFILES_DIR, "#{profile_name}.yml")

        unless File.exist?(profile_file)
          raise ProfileError,
                "Profile not found: #{profile_name} (expected: #{profile_file})"
        end

        profile = Profile.load_from_file(profile_file)

        # Cache the loaded profile if caching is enabled
        if ENABLE_CACHE
          @cache_mutex.synchronize do
            @cache[profile_name] = profile
            @access_order.push(profile_name)
          end
        end

        profile
      end

      # Evict least recently used profile from cache
      # @return [void]
      def evict_lru_if_full
        return if @cache.length < MAX_CACHE_SIZE

        # Remove the oldest accessed profile
        lru_profile = @access_order.shift
        @cache.delete(lru_profile)
      end

      # Calculate total cache operations for hit ratio calculation
      # @return [Integer] total cache operations
      def total_cache_operations
        @cache_hits + @cache_misses
      end
    end
  end
end

