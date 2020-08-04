# frozen_string_literal: true

# implementation based on the Destroy All Software series on testing:
#  https://www.destroyallsoftware.com/screencasts/catalog/finding-missing-tests

GREEN = "\e[32m"
RED = "\e[31m"
RESET = "\e[0m"

class ComparisonAssertion
    def initialize(actual, expected = nil)
        @actual = actual
        @expected = expected
    end

    def ==(expected)
        unless @actual == expected
            raise AssertionError.new(
                "expected #{expected.inspect} but got #{@actual.inspect}"
            )
        end
    end

    def eq
        self.==(@expected)
    end

    def self.should(actual, expected)
        compare = ComparisonAssertion.new(actual, expected)
        compare.eq
    end
end

class AssertionError < RuntimeError
end

def context(description, **metadata, &block)
  context = Context.new(description, metadata, block)
  context.run()
end

class Context
    def initialize(description, metadata, block, lets: {}, befores: [], afters: [])
      @description = description
      @metadata = metadata
      @block = block
      @lets = {}.merge lets # copy over, not assign, e.g. newly introduced 'lets' should
                        # should not pollute higher scopes
      @lets_cache = {}
      @befores = [] + befores
      @afters = [] + afters
    end

    def run
      instance_eval(&@block)
    end

    def let(name, &block)
      @lets[name] = block
    end

    def before(&block)
      @befores << block
    end

    def after(&after)
      @afters << after
    end

    def describe(description, **metadata, &block)
      describe = Describe.new(description, metadata.merge(@metadata), block,
                              lets: @lets, befores: @befores, afters: @afters)
      describe.run()
    end

    def it(description, **metadata, &block)
      describe = Describe.new(description, metadata.merge(@metadata), block,
                              lets: @lets, befores: @befores, afters: @afters)

      describe.it(description, &block)
    end

    def context(description, **metadata, &block)
      Context.new(description, metadata.merge(@metadata), block,
                  lets: @lets, befores: @befores, afters: @afters)
    end

    def method_missing(name, args = [])
      if @lets_cache.key?(name)
        @lets_cache.fetch(name)
      else
        value = instance_eval(&@lets.fetch(name) { super })
        @lets_cache[name] = value
        value
      end
    end
end

def describe(description, **metadata, &block)
    describe = Describe.new(description, metadata, block)
    describe.run()
end

class Describe < Context
  @lets = {}

  def initialize(description, metadata, block, lets: {}, befores: [], afters: [])
    super(description, metadata, block, lets: lets, befores: befores, afters: afters)
  end

  def run
    instance_eval(&@block)
  end

  def context(description, **metadata, &block)
    context = Context.new(description, metadata.merge(@metadata), block,
                          lets: @lets, befores: @befores, afters: @afters)
    context.run()
  end

  def it(should, **metadata, &block)
    it = It.new(should, metadata.merge(@metadata), block,
                lets: @lets, befores: @befores, afters: @afters)
    it.run()
  end
end

class It < Context
  @lets = {}

  def initialize(description, metadata, block, lets: {}, befores: [], afters: [])
    super(description, metadata, block, lets: lets, befores: befores, afters: afters)
  end

  def expect(actual = nil, &block)
    Actual.new(actual || block)
  end

  def before
    raise RuntimeError("'before' is not valid inside the 'it' expression")
  end

  def after
    raise RuntimeError("'after' is not valid inside the 'it' expression")
  end

  def eq(expected)
    Expectations::Equals.new(expected, @description, @metadata, nil,
                             lets: @lets, befores: @befores, afters: @afters)
  end

  def raise_error(exception_class)
    Expectations::Error.new(exception_class, @description, @metadata, nil,
                            lets: @lets, befores: @befores, afters: @afters)
  end

  def method_missing(name, args = [])
    super
  end

  def run()
    begin
        $stdout.write "  - #{@description}\n"

        @befores.each { |before| instance_eval(&before) }

        instance_eval(&@block)
        puts " #{GREEN}(ok)#{RESET}"
    rescue Exception => e
        puts " #{RED}(fail)#{RESET}"
        if (@metadata.length > 0)
          puts "\tmetadata: #{@metadata}"
        end
        puts [
          "#{RED}* backtrace:#{RESET}",
          e.backtrace.reverse.map { |line| "#{RED}|#{RESET} #{line}" },
          "#{RED}* #{e}#{RESET}"
        ].flatten.map { |line| "\t#{line}" }.join("\n")
    ensure
      @afters.each { |after| instance_eval(&after) }
    end
  end
end

class Actual
  def initialize(actual)
    @actual = actual
  end

  def to(expectations)
    expectations.run(@actual)
  end
end

class Expectations
  class Equals < Context
    def initialize(expected, description, metadata, block, lets: {})
      super(description, metadata, block, lets: lets, befores: [], afters: [])
      @expected = expected
    end

    def run(actual)
      a = actual
      if (actual.is_a?(Proc))
        a = instance_eval(&actual)
      end
      ComparisonAssertion.should(a, @expected)
    end
  end

  class Error < Context
    def initialize(exception_class, description, metadata, block, lets: {})
      super(description, metadata, block, lets: lets, befores: [], afters: [])
      @exception_class = exception_class
    end

    def run(actual)
      if (actual.is_a?(Proc))
        begin
          instance_eval(&actual)
        rescue Exception => e
          if (!e.is_a?(@exception_class))
            raise AssertionError(
              "#{@exception_class.class.name} did not match that of #{e.class.name}"
            )
          end
        end
      else
        raise AssertionError.new(
            "raise_error takes a block which expects to: raise SomeException"
        )
      end
    end
  end
end

# a simple version is commented out below:
# def describe(description, &block)
#     puts description
#     block.call
# end

# lookup "An Editor From Scratch"

# def it(description, &block)
#     begin
#         $stdout.write "  - #{description}"
#         block.call
#         puts " #{GREEN}(ok)#{RESET}"
#     rescue Exception => e
#         puts " #{RED}(fail)#{RESET}"
#         puts [
#           "#{{RED}* backtrace:#{RESET}}",
#           e.backtrace.reverse.map { |line| "#{RED}|#{{RESET} #{line}}" },
#           "#{RED}* #{e}#{RESET}"
#         ].flatten.map { |line| "\t#{line}" }.join("\n")
#     end
# end
#
# class Object
#     def should(description, eq = nil)
#         if eq != nil
#             ComparisonAssertion.should(self, eq)
#         else
#             ComparisonAssertion.new(self, eq)
#         end
#     end
# end
