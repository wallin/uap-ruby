# frozen_string_literal: true

require 'monitor'

module UserAgentParser
  # In-memory cache with configurable max item size.
  # Aim to be API compatible with ActiveSupport::Cache::Store
  class Cache
    MAX_KEYS = 5000 # keys
    PURGE_FRACTION = 3 # one third

    def initialize(max_keys: nil)
      @store = {}
      @max_keys = max_keys || MAX_KEYS
      @monitor = Monitor.new
    end

    def fetch(key)
      value = read(key)
      if block_given? && value.nil?
        value = yield
        write(key, value)
      end
      value
    end

    def clear
      synchronize { @store.clear }
    end

    # Remove a fraction of the total keys, not looking at when they were last
    # used
    def prune(target_fraction)
      store_size = @store.size
      return unless store_size >= @max_keys
      keys_to_delete = @store.keys.first(store_size / target_fraction)
      keys_to_delete.each { |key| @store.delete(key) }
    end

    def read(key)
      @store[key]
    end

    def write(key, value)
      synchronize do
        prune(PURGE_FRACTION)
        @store[key] = value
      end
    end

    private

    def synchronize(&block)
      @monitor.synchronize(&block)
    end
  end
end
