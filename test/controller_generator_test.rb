require 'rails/generators/test_case'
require 'generators/rails/strong_parameters_controller_generator'

class StrongParametersControllerGeneratorTest < Rails::Generators::TestCase
  tests Rails::Generators::StrongParametersControllerGenerator
  arguments %w(User name:string age:integer --orm=none)
  destination File.expand_path("../tmp", File.dirname(__FILE__))
  setup :prepare_destination

  def test_controller_content
    run_generator

    assert_file "app/controllers/users_controller.rb" do |content|

      assert_instance_method :create, content do |m|
        assert_match '@user = User.new(user_params)', m
        assert_match '@user.save', m
        assert_match '@user.errors', m
      end

      assert_instance_method :update, content do |m|
        assert_match '@user = User.find(params[:id])', m
        assert_match '@user.update_attributes(user_params)', m
        assert_match '@user.errors', m
      end

      assert_match 'def user_params', content
      assert_match 'params.require(:user).permit(:age, :name)', content
    end
  end
end
