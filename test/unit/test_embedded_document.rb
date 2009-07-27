require 'test_helper'

class Grandparent
  include MongoMapper::EmbeddedDocument
  key :grandparent, String
end

class Parent < Grandparent
  include MongoMapper::EmbeddedDocument
  key :parent, String
end

class Child < Parent
  include MongoMapper::EmbeddedDocument
  key :child, String
end

class OtherChild < Parent
  include MongoMapper::EmbeddedDocument
  key :other_child, String
end

class EmbeddedDocumentTest < Test::Unit::TestCase
  context "Including MongoMapper::EmbeddedDocument" do
    setup do
      @klass = Class.new do
        include MongoMapper::EmbeddedDocument
      end
    end
    
    should "clear out document default keys" do
      @klass.keys.size.should == 0
    end
  end
  
  context "parent_model" do
    should "be nil if none of parents ancestors include EmbeddedDocument" do
      parent = Class.new
      document = Class.new(parent) do
        include MongoMapper::EmbeddedDocument
      end
      document.parent_model.should be_nil
    end
    
    should "find parent" do
      Parent.parent_model.should == Grandparent
      Child.parent_model.should == Parent
    end
  end
  
  context "defining a key" do
    setup do
      @document = Class.new do
        include MongoMapper::EmbeddedDocument
      end
    end
    
    should "work" do
      key = @document.key(:name, String)
      key.name.should == 'name'
      key.type.should == String
      key.should be_instance_of(MongoMapper::Key)
    end
    
    should "work with options" do
      key = @document.key(:name, String, :required => true)
      key.options[:required].should be(true)
    end
    
    should "be tracked per document" do
      @document.key(:name, String)
      @document.key(:age, Integer)
      @document.keys['name'].name.should == 'name'
      @document.keys['name'].type.should == String
      @document.keys['age'].name.should == 'age'
      @document.keys['age'].type.should == Integer
    end
    
    should "be redefinable" do
      @document.key(:foo, String)
      @document.keys['foo'].type.should == String
      @document.key(:foo, Integer)
      @document.keys['foo'].type.should == Integer
    end
  end
  
  context "keys" do
    should "be inherited" do
      Grandparent.keys.keys.should == ['grandparent']
      Parent.keys.keys.sort.should == ['grandparent', 'parent']
      Child.keys.keys.sort.should  == ['child', 'grandparent', 'parent']
    end
    
    should "propogate to subclasses if key added after class definition" do
      Grandparent.key :_type, String
      
      Grandparent.keys.keys.sort.should == ['_type', 'grandparent']
      Parent.keys.keys.sort.should      == ['_type', 'grandparent', 'parent']
      Child.keys.keys.sort.should       == ['_type', 'child', 'grandparent', 'parent']
    end
  end
  
  context "subclasses" do
    should "default to nil" do
      Child.subclasses.should be_nil
    end
    
    should "be recorded" do
      Grandparent.subclasses.should == [Parent]
      Parent.subclasses.should      == [Child, OtherChild]
    end
  end

  context "An instance of an embedded document" do
    setup do
      @document = Class.new do
        include MongoMapper::EmbeddedDocument

        key :name, String
        key :age, Integer
      end
    end

    context "being initialized" do
      should "accept a hash that sets keys and values" do
        doc = @document.new(:name => 'John', :age => 23)
        doc.attributes.should == {'name' => 'John', 'age' => 23}
      end

      should "not throw error if initialized with nil" do
        doc = @document.new(nil)
      end
    end

    context "mass assigning keys" do
      should "update values for keys provided" do
        doc = @document.new(:name => 'foobar', :age => 10)
        doc.attributes = {:name => 'new value', :age => 5}
        doc.attributes[:name].should == 'new value'
        doc.attributes[:age].should == 5
      end

      should "not update values for keys that were not provided" do
        doc = @document.new(:name => 'foobar', :age => 10)
        doc.attributes = {:name => 'new value'}
        doc.attributes[:name].should == 'new value'
        doc.attributes[:age].should == 10
      end

      should "raise undefined method if no key exists" do
        doc = @document.new(:name => 'foobar', :age => 10)
        lambda {
          doc.attributes = {:name => 'new value', :foobar => 'baz'}
        }.should raise_error(NoMethodError)
      end

      should "not ignore keys that have methods defined" do
        @document.class_eval do
          attr_writer :password

          def passwd
            @password
          end
        end

        doc = @document.new(:name => 'foobar', :password => 'secret')
        doc.passwd.should == 'secret'
      end

      should "typecast key values" do
        doc = @document.new(:name => 1234, :age => '21')
        doc.name.should == '1234'
        doc.age.should == 21
      end
    end

    context "requesting keys" do
      should "default to empty hash" do
        doc = @document.new
        doc.attributes.should == {}
      end

      should "return all keys that aren't nil" do
        doc = @document.new(:name => 'string', :age => nil)
        doc.attributes.should == {'name' => 'string'}
      end
    end
    
    context "key shorcuts" do
      should "be able to read key with []" do
        doc = @document.new(:name => 'string')
        doc[:name].should == 'string'
      end
      
      should "be able to write key value with []=" do
        doc = @document.new
        doc[:name] = 'string'
        doc[:name].should == 'string'
      end
    end
    
    context "indifferent access" do
      should "be enabled for keys" do
        doc = @document.new(:name => 'string')
        doc.attributes[:name].should == 'string'
        doc.attributes['name'].should == 'string'
      end
    end

    context "reading an attribute" do
      should "work for defined keys" do
        doc = @document.new(:name => 'string')
        doc.name.should == 'string'
      end

      should "raise no method error for undefined keys" do
        doc = @document.new
        lambda { doc.fart }.should raise_error(NoMethodError)
      end

      should "be accessible for use in the model" do
        @document.class_eval do
          def name_and_age
            "#{read_attribute(:name)} (#{read_attribute(:age)})"
          end
        end

        doc = @document.new(:name => 'John', :age => 27)
        doc.name_and_age.should == 'John (27)'
      end
    end

    context "reading an attribute before typcasting" do
      should "work for defined keys" do
        doc = @document.new(:name => 12)
        doc.name_before_typecast.should == 12
      end

      should "raise no method error for undefined keys" do
        doc = @document.new
        lambda { doc.foo_before_typecast }.should raise_error(NoMethodError)
      end

      should "be accessible for use in a document" do
        @document.class_eval do
          def untypcasted_name
            read_attribute_before_typecast(:name)
          end
        end

        doc = @document.new(:name => 12)
        doc.name.should == '12'
        doc.untypcasted_name.should == 12
      end
    end

    context "writing an attribute" do
      should "work for defined keys" do
        doc = @document.new
        doc.name = 'John'
        doc.name.should == 'John'
      end

      should "raise no method error for undefined keys" do
        doc = @document.new
        lambda { doc.fart = 'poof!' }.should raise_error(NoMethodError)
      end

      should "typecast value" do
        doc = @document.new
        doc.name = 1234
        doc.name.should == '1234'
        doc.age = '21'
        doc.age.should == 21
      end
      
      should "be accessible for use in the model" do
        @document.class_eval do
          def name_and_age=(new_value)
            new_value.match(/([^\(\s]+) \((.*)\)/)
            write_attribute :name, $1
            write_attribute :age, $2
          end
        end

        doc = @document.new
        doc.name_and_age = 'Frank (62)'
        doc.name.should == 'Frank'
        doc.age.should == 62
      end
    end # writing an attribute
    
    context "equality" do
      should "be true if all keys and values are equal" do
        doc1 = @document.new(:name => 'John', :age => 27)
        doc2 = @document.new(:name => 'John', :age => 27)
        doc1.should == doc2
      end

      should "be false if not all the keys and values are equal" do
        doc1 = @document.new(:name => 'Steve', :age => 27)
        doc2 = @document.new(:name => 'John', :age => 27)
        doc1.should_not == doc2
      end
    end
  end # instance of a embedded document
end