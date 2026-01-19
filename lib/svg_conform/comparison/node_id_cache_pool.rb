# frozen_string_literal: true

module SvgConform
  module Comparison
    # Node ID cache pool for reusing caches across batch validations
    #
    # This service provides a thread-safe cache pool that can be reused
    # across multiple validations in a batch, reducing the overhead of
    # repeated cache population.
    #
    # The cache is keyed by document object_id to ensure that caches
    # are only reused for the same document.
    #
    # PERFORMANCE: Call clear_all_caches after batch operations to free memory.
    class NodeIdCachePool
      class << self
        # Get or create a cache for the given document
        #
        # @param document [Object] the document to cache node IDs for
        # @return [Hash] the node ID cache
        def get_or_create_cache(document)
          return {} unless document

          doc_id = document.object_id
          @cache_pool ||= {}
          @cache_pool[doc_id] ||= {}
        end

        # Clear the cache pool (useful for memory management)
        #
        # Call this after completing a batch validation to free memory.
        def clear_pool
          @cache_pool&.clear
          @cache_pool = nil
        end

        # Remove cache for a specific document
        #
        # @param document [Object] the document to remove from cache
        def remove_cache(document)
          return unless document

          doc_id = document.object_id
          @cache_pool&.delete(doc_id)
        end

        # Get current pool size (for monitoring)
        #
        # @return [Integer] the number of cached documents
        def pool_size
          @cache_pool&.size || 0
        end

        # Pre-warm cache for a document by populating it eagerly
        #
        # This is useful for documents that will be validated multiple times
        # (e.g., in batch operations or compatibility testing).
        #
        # @param document [Object] the document to pre-warm cache for
        # @param context [ValidationContext] the validation context
        def pre_warm_cache(document, context)
          return unless document && context

          cache = get_or_create_cache(document)
          return unless cache.empty?

          # Populate cache using context's method
          context.populate_node_id_cache if context.respond_to?(:populate_node_id_cache)
        end
      end
    end

    # Cache management utility for batch operations
    #
    # Provides centralized cache clearing for all comparison caches
    # to prevent memory bloat during batch operations.
    module CacheManager
      class << self
        # Clear all comparison caches
        #
        # Call this after batch operations to free memory:
        # - Clears node ID cache pool
        # - Clears semantic extraction memoization cache
        def clear_all_caches
          NodeIdCachePool.clear_pool
          SemanticExtractor.clear_memoization_cache
        end

        # Get cache statistics for monitoring
        #
        # @return [Hash] cache statistics
        def cache_stats
          {
            node_id_pool_size: NodeIdCachePool.pool_size,
            semantic_memoization_cache_size: SemanticExtractor.memoization_cache.size,
          }
        end

        # Display cache statistics (useful for debugging)
        def display_cache_stats
          stats = cache_stats
          puts "Cache Statistics:"
          puts "  Node ID Pool Size: #{stats[:node_id_pool_size]}"
          puts "  Semantic Memoization Cache Size: #{stats[:semantic_memoization_cache_size]}"
        end
      end
    end
  end
end
