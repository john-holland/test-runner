module Factories
    module User
        @_User = Struct.new(:name)
        def self.with_name(name)
            @_User.new(name)
        end
    end
end