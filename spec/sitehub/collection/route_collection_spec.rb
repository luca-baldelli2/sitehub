require 'sitehub/collection/route_collection'
require 'sitehub/forward_proxy'

class SiteHub
  describe Collection::RouteCollection do
    let(:route_without_rule) { ForwardProxy.new(url: :url, id: :id, sitehub_cookie_name: :cookie_name) }

    it 'is a collection' do
      expect(subject).to be_a(Collection)
    end

    describe '#add' do
      it 'stores a value' do
        subject.add :id, route_without_rule
        expect(subject[:id]).to be(route_without_rule)
      end
    end

    describe '#transform' do
      it "replaces the stores values with what's returned from the block" do
        subject.add :id, route_without_rule
        value_before_transform = subject[:id]
        subject.transform do |value|
          expect(value).to be(value_before_transform)
          :transformed_value
        end

        expect(subject[:id]).to eq(:transformed_value)
      end
    end

    describe '#valid?' do
      context 'route added' do
        it 'returns true' do
          subject.add :id, route_without_rule
          expect(subject).to be_valid
        end
      end

      context 'no routes added' do
        it 'returns false' do
          expect(subject).to_not be_valid
        end
      end
    end

    describe '#resolve' do
      context 'no rule on route' do
        it 'returns the route' do
          route_without_rule = ForwardProxy.new(url: :url, id: :id, sitehub_cookie_name: :cookie_name)
          subject.add(:id, route_without_rule)
          expect(subject.resolve({})).to be(route_without_rule)
        end
      end
      context 'rule on route' do
        it 'passes the environment to the rule' do
          request_env = {}
          rule = proc { |env| env[:env_passed_in] = true }

          proxy = ForwardProxy.new(url: :url,
                                   id: :id,
                                   sitehub_cookie_name: :cookie_name)
          proxy.rule(rule)
          subject.add(:id, proxy)
          subject.resolve(env: request_env)
          expect(request_env[:env_passed_in]).to eq(true)
        end

        context 'rule applies' do
          it 'returns the route' do
            route_with_rule = ForwardProxy.new(url: :url,
                                               id: :id,
                                               rule: proc { true },
                                               sitehub_cookie_name: :cookie_name)
            subject.add(:id, route_with_rule)
            expect(subject.resolve({})).to be(route_with_rule)
          end
        end

        context 'rule does not apply' do
          it 'returns nil' do
            route_with_rule = ForwardProxy.new(url: :url,
                                               id: :id,
                                               sitehub_cookie_name: :cookie_name,
                                               rule: proc { false })
            subject.add(:id, route_with_rule)
            expect(subject.resolve({})).to eq(nil)
          end
        end
      end
    end
  end
end
