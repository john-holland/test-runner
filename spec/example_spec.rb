require_relative "../runner"
require_relative "./factories"

context "some context" do
  let(:five) { 5 }
  let(:random) { rand() }

  before {
    puts "before describe"
  }

  describe "some examples" do
      let(:user) { Factories::User.with_name("guy smiley") }

      before {
        puts "before test"
      }

      it "can use factories" do
        expect(user.name).to eq "guy smiley"
      end

      it "can pass" do
          expect(1 + 1).to eq 2
      end

      it "can use eq" do
          expect(1 + 1).to eq 2
      end

      it "can use let" do
        expect(five).to eq 5
      end

      context "can override lets" do
        before {
          "before nested"
        }
        let(:five) { 6 }
        let(:seven) { five + 1 }

        it "like this" do
          expect(five).to eq 6
        end

        it "and those can use other similarly scoped lets" do
          expect(seven).to eq 7
        end

        context "and even if we nest a lot it should be fine" do
          let(:eight) { seven + 1}

          it "like this" do
            expect(eight).to eq 8
          end
        end
      end

      it "can use let with stable values" do
        our_random = random
        expect(our_random).to eq random
      end

      it "can fail" do
          expect(1 + 1).to eq 3
      end

      it "can expect exceptions", test: 5 do
        expect do
          raise RuntimeError.new("expect me!")
        end.to raise_error RuntimeError
      end

      it "can pass after failing" do
      end

      after {
        puts "this don't get called as this implementation of the rspec ... rspec
         is implemented as immediately invoked keywords, in order."
      }

  end
end
