# frozen_string_literal: true

module SvgConform
  # Cache for requirement classification results
  # Instance-level (per SaxValidationHandler) to avoid shared mutable state
  # No mutexes needed - each handler has its own cache
  class ClassificationCache
    def initialize
      @cache = {}
    end

    # Fetch from cache or compute the value
    def fetch(key)
      @cache[key] ||= yield
    end

    # Clear specific key or entire cache
    def clear(key = nil)
      if key
        @cache.delete(key)
      else
        @cache.clear
      end
    end

    # Return number of cached entries
    def size
      @cache.size
    end

    # Check if key exists in cache
    def key?(key)
      @cache.key?(key)
    end
  end
end
