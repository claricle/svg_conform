# frozen_string_literal: true

require "lutaml/model"
require_relative "../remediation_result"

module SvgConform
  module Remediations
    # Base class for all remediations using lutaml-model serialization
    class BaseRemediation < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :description, :string
      attribute :targets, :string, collection: true
      attribute :config, :hash
      attribute :type, :string, polymorphic_class: true, default: -> {
        self.class.name.split("::").last
      }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "targets", to: :targets
        map "config", to: :config
        map "type", to: :type
      end

      def apply(document, context)
        raise NotImplementedError, "Subclasses must implement apply"
      end

      # Check if this remediation should execute based on failed requirements
      def should_execute?(failed_requirements)
        failed_requirement_ids = failed_requirements.map(&:requirement_id)
        targets.any? { |req_id| failed_requirement_ids.include?(req_id) }
      end

      # Execute the remediation and return a result
      def execute(document, failed_requirements)
        unless should_execute?(failed_requirements)
          return RemediationResult.new(
            remediation_id: @id,
            success: false,
            failed_requirements: [],
            message: "Remediation not applicable",
          )
        end

        begin
          context = { failed_requirements: failed_requirements }
          changes_made = apply(document, context)

          RemediationResult.new(
            remediation_id: @id,
            success: true,
            failed_requirements: failed_requirements,
            message: "Remediation applied successfully",
            changes_made: changes_made,
          )
        rescue StandardError => e
          RemediationResult.new(
            remediation_id: @id,
            success: false,
            failed_requirements: failed_requirements,
            message: "Remediation failed: #{e.message}",
            error: e,
          )
        end
      end

      def to_s
        "#{id}: #{description} (targets: #{targets.join(', ')})"
      end

      protected

      def element?(node)
        node.respond_to?(:name) && node.name
      end

      def get_attribute(node, attr_name)
        return nil unless node.respond_to?(:[])

        node[attr_name]
      end

      def set_attribute(node, attr_name, value)
        return unless node.respond_to?(:[]=)

        node[attr_name] = value
      end

      def has_attribute?(node, attr_name)
        return false unless node.respond_to?(:[])

        !node[attr_name].nil?
      end

      def find_nodes(document, &)
        nodes = []
        traverse_nodes(document, nodes, &)
        nodes
      end

      # Helper method to remove attribute
      def remove_attribute(node, name)
        if node.respond_to?(:remove_attribute)
          node.remove_attribute(name)
          true
        elsif node.respond_to?(:[]=) && node.respond_to?(:[])
          # Fallback for different implementations
          node[name] = nil
          true
        else
          false
        end
      end

      # Helper method to remove node
      def remove_node(node)
        return false unless node.respond_to?(:remove)

        node.remove
        true
      end

      # Helper method to replace node
      def replace_node(node, replacement)
        return false unless node.respond_to?(:replace)

        node.replace(replacement)
        true
      end

      # Helper method to create comment node
      def create_comment(document, text)
        document.create_comment(text)
      end

      def log_change(type, message, node = nil)
        {
          type: type,
          message: message,
          node: node&.name || "unknown",
          node_attributes: node.respond_to?(:attributes) ? node.attributes : nil,
          timestamp: Time.now,
        }
      end

      private

      def traverse_nodes(node, nodes, &block)
        return unless node

        # Add node if it matches the block condition
        nodes << node if yield(node)

        # Traverse children if the node supports it
        if node.respond_to?(:children)
          node.children.each { |child| traverse_nodes(child, nodes, &block) }
        elsif node.respond_to?(:each)
          node.each { |child| traverse_nodes(child, nodes, &block) }
        end
      end
    end
  end
end
