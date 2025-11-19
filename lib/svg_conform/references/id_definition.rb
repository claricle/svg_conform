# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  module References
    # Represents an ID definition in the SVG document
    class IdDefinition < Lutaml::Model::Serializable
      attribute :id_value, :string
      attribute :element_name, :string
      attribute :line_number, :integer
      attribute :column_number, :integer

      yaml do
        map "id_value", to: :id_value
        map "element_name", to: :element_name
        map "line_number", to: :line_number
        map "column_number", to: :column_number
      end

      json do
        map "id_value", to: :id_value
        map "element_name", to: :element_name
        map "line_number", to: :line_number
        map "column_number", to: :column_number
      end

      def to_h
        {
          id_value: id_value,
          element_name: element_name,
          line_number: line_number,
          column_number: column_number,
        }
      end
    end
  end
end