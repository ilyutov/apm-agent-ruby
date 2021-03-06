# frozen_string_literal: true

require 'securerandom'

module ElasticAPM
  # @api private
  class Transaction
    extend Deprecations

    DEFAULT_TYPE = 'custom'

    # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
    def initialize(
      name = nil,
      type = nil,
      sampled: true,
      context: nil,
      tags: nil,
      trace_context: nil
    )
      @name = name
      @type = type || DEFAULT_TYPE

      @sampled = sampled

      @context = context || Context.new # TODO: Lazy generate this?
      Util.reverse_merge!(@context.tags, tags) if tags

      if trace_context
        @parent_id = trace_context.span_id
        @trace_context = trace_context
      else
        @trace_context = TraceContext.for_transaction(sampled: sampled)
      end

      @started_spans = 0
      @dropped_spans = 0

      @notifications = [] # for AS::Notifications
    end
    # rubocop:enable Metrics/ParameterLists, Metrics/MethodLength

    attr_accessor :name, :type, :result

    attr_reader :context, :duration, :started_spans, :dropped_spans,
      :timestamp, :trace_context, :notifications, :parent_id

    def id
      trace_context.span_id
    end

    def sampled?
      @sampled
    end

    def stopped?
      !!duration
    end

    def done?
      stopped?
    end

    deprecate :done?, :stopped?

    def trace_id
      trace_context&.trace_id
    end

    # life cycle

    def start(timestamp = Util.micros)
      @timestamp = timestamp
      self
    end

    def stop(end_timestamp = Util.micros)
      raise 'Transaction not yet start' unless timestamp
      @duration = end_timestamp - timestamp
      self
    end

    def done(result = nil, end_time: Util.micros)
      stop end_time
      self.result = result if result
      self
    end

    def ensure_parent_id
      @parent_id ||= SecureRandom.hex(8)
      @parent_id
    end

    # spans

    def inc_started_spans!
      @started_spans += 1
    end

    def inc_dropped_spans!
      @dropped_spans += 1
    end

    def max_spans_reached?(config)
      started_spans > config.transaction_max_spans
    end

    # context

    def add_response(*args)
      context.response = Context::Response.new(*args)
    end

    def inspect
      "<ElasticAPM::Transaction id:#{id}" \
        " name:#{name.inspect} type:#{type.inspect}>"
    end
  end
end
