# frozen_string_literal: true

RSpec.describe SvgConform::ValidationContext do
  let(:document) { nil }
  let(:profile) { instance_double(SvgConform::Profile) }
  let(:context) { described_class.new(document, profile) }

  describe "#state_for" do
    # Create test requirement with nested State class
    let(:requirement_with_state) do
      req_class = Class.new(SvgConform::Requirements::BaseRequirement) do
        def id
          "test_requirement"
        end
      end

      # Define State class as a proper constant
      req_class.const_set(:State, Class.new do
        attr_accessor :collected_items

        def initialize
          @collected_items = []
        end
      end)

      req_class.new
    end

    it "creates a fresh State instance on first access" do
      state = context.state_for(requirement_with_state)
      expect(state).to be_a(requirement_with_state.class::State)
      expect(state.collected_items).to eq([])
    end

    it "returns the same State instance on subsequent accesses for same requirement class" do
      state1 = context.state_for(requirement_with_state)
      state1.collected_items << "item1"
      state2 = context.state_for(requirement_with_state)
      expect(state2).to be(state1)
      expect(state2.collected_items).to eq(["item1"])
    end

    it "creates separate State instances for different requirement classes" do
      req1_class = Class.new(SvgConform::Requirements::BaseRequirement) do
        def id
          "req1"
        end
      end
      req1_class.const_set(:State, Class.new do
        attr_accessor :data

        def initialize
          @data = []
        end
      end)

      req2_class = Class.new(SvgConform::Requirements::BaseRequirement) do
        def id
          "req2"
        end
      end
      req2_class.const_set(:State, Class.new do
        attr_accessor :items

        def initialize
          @items = []
        end
      end)

      req1 = req1_class.new
      req2 = req2_class.new

      state1 = context.state_for(req1)
      state2 = context.state_for(req1)
      state3 = context.state_for(req2)

      expect(state1).to be(state2)
      expect(state1).not_to be(state3)
      expect(state2).not_to be(state3)
    end

    it "uses requirement class as key, not instance" do
      req1_instance1 = requirement_with_state
      req1_instance2 = requirement_with_state.class.new

      state1 = context.state_for(req1_instance1)
      state1.collected_items << "from_instance1"

      state2 = context.state_for(req1_instance2)

      # Both instances of the same requirement class should share state
      expect(state1).to be(state2)
      expect(state2.collected_items).to eq(["from_instance1"])
    end

    context "with requirement that lacks nested State class" do
      let(:requirement_without_state) do
        Class.new(SvgConform::Requirements::BaseRequirement) do
          def id
            "no_state_requirement"
          end
        end.new
      end

      it "raises an error when State class is not defined" do
        expect do
          context.state_for(requirement_without_state)
        end.to raise_error(NameError, /uninitialized constant.*State/)
      end
    end
  end

  describe "state lifecycle" do
    let(:requirement_class) do
      req_class = Class.new(SvgConform::Requirements::BaseRequirement) do
        def id
          "counter_requirement"
        end
      end

      req_class.const_set(:State, Class.new do
        attr_accessor :counter

        def initialize
          @counter = 0
        end
      end)

      req_class
    end

    it "creates fresh state for each validation context instance" do
      requirement = requirement_class.new

      context1 = described_class.new(nil, profile)
      state1 = context1.state_for(requirement)
      state1.counter = 42

      context2 = described_class.new(nil, profile)
      state2 = context2.state_for(requirement)

      # Different contexts should have different state instances
      expect(state1).not_to be(state2)
      expect(state2.counter).to eq(0)
    end

    it "prevents state pollution across validations" do
      requirement = requirement_class.new

      # First validation
      context1 = described_class.new(nil, profile)
      state1 = context1.state_for(requirement)
      state1.counter = 100

      # Second validation with same profile
      context2 = described_class.new(nil, profile)
      state2 = context2.state_for(requirement)

      # State should be fresh, not polluted by first validation
      expect(state2.counter).to eq(0)
    end
  end

  describe "#node_structurally_invalid?" do
    it "returns false for nodes not marked as structurally invalid" do
      # In SAX mode (document = nil), simple objects return nil from node_id generator
      node = Object.new
      expect(context.node_structurally_invalid?(node)).to be false
    end
  end

  describe "#mark_node_structurally_invalid" do
    it "marks a node as structurally invalid" do
      # Use a node-like object with a stable path_id for tracking
      node = Object.new
      def node.path_id
        "test_node_1"
      end

      context.mark_node_structurally_invalid(node)
      # After marking, the node should be tracked as structurally invalid
      expect(context.node_structurally_invalid?(node)).to be true
    end
  end

  describe "#register_id" do
    it "registers an ID in the reference manifest" do
      context.register_id("test_id", element_name: "svg", line_number: 1,
                                     column_number: 1)
      expect(context.id_defined?("test_id")).to be true
    end
  end

  describe "#register_reference" do
    it "registers a reference in the manifest" do
      # Use a concrete reference type
      reference = SvgConform::References::InternalFragmentReference.new(
        value: "#target",
        element_name: "use",
        attribute_name: "href",
        line_number: 1,
        column_number: 1,
      )

      context.register_reference(reference)
      # Verify reference was added - the manifest should now track this reference
      expect(context.reference_manifest).to be_a(SvgConform::References::ReferenceManifest)
    end
  end

  describe "#id_defined?" do
    it "returns false for undefined IDs" do
      expect(context.id_defined?("nonexistent")).to be false
    end

    it "returns true for registered IDs" do
      context.register_id("test_id", element_name: "svg")
      expect(context.id_defined?("test_id")).to be true
    end
  end

  describe "#add_error" do
    it "adds an error to the context" do
      node = Object.new
      context.add_error(
        node: node,
        message: "test error",
        requirement_id: "test",
      )

      expect(context.has_errors?).to be true
      expect(context.errors.first.message).to eq("test error")
    end
  end

  describe "#add_warning" do
    it "adds a warning to the context" do
      node = Object.new
      context.add_warning(
        rule: "test_rule",
        node: node,
        message: "test warning",
      )

      expect(context.has_warnings?).to be true
      expect(context.warnings.first.message).to eq("test warning")
    end
  end

  describe "#add_notice" do
    it "adds a notice to the context" do
      node = Object.new
      context.add_notice(
        rule: "test_rule",
        node: node,
        message: "test notice",
      )

      expect(context.infos.first.message).to eq("test notice")
    end
  end

  describe "#has_errors?" do
    it "returns false when no errors" do
      expect(context.has_errors?).to be false
    end

    it "returns true when errors are added" do
      node = Object.new
      context.add_error(node: node, message: "error", requirement_id: "test")
      expect(context.has_errors?).to be true
    end
  end

  describe "#has_warnings?" do
    it "returns false when no warnings" do
      expect(context.has_warnings?).to be false
    end

    it "returns true when warnings are added" do
      node = Object.new
      context.add_warning(rule: "test", node: node, message: "warning")
      expect(context.has_warnings?).to be true
    end
  end

  describe "#add_fix" do
    it "stores fix in fixes array" do
      fix = -> { "some action" }
      context.add_fix(fix)
      expect(context.fixes).to eq([fix])
    end
  end

  describe "#has_fixes?" do
    it "returns false when no fixes" do
      expect(context.has_fixes?).to be false
    end

    it "returns true when fixes are added" do
      context.add_fix(-> { "action" })
      expect(context.has_fixes?).to be true
    end
  end
end
