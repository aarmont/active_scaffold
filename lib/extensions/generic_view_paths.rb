# The view_paths functionality in Rails 2.0.x doesn't support
# the idea of a fallback generic template file, such as what make ActiveScaffold
# work. This patch adds generic_view_paths, which are folders containing templates
# that may apply to all controllers.
#
# There is one major difference with generic_view_paths, though. They should
# *not* be used unless the action has been explicitly defined in the controller.
# This is in contrast to how Rails will normally bypass the controller if it sees
# a partial.

class ActionController::Base
  class_inheritable_accessor :generic_view_paths
  self.generic_view_paths = []
end

# #find_full_template_path was refactored into the TemplateFinder Class in Rails 2.1
if ActionView::Base.private_instance_methods.include?("find_full_template_path") # RAILS 2.0
  class ActionView::Base
    private
    def find_full_template_path_with_generic_paths(template_path, extension)
      path = find_full_template_path_without_generic_paths(template_path, extension)
      if path and not path.empty?
        path
      elsif search_generic_view_paths?
        template_file = File.basename("#{template_path}.#{extension}")
        path = find_generic_base_path_for(template_file)
        path ? "#{path}/#{template_file}" : ""
      else
        ""
      end
    end
    alias_method_chain :find_full_template_path, :generic_paths

    # Returns the view path that contains the given relative template path.
    def find_generic_base_path_for(template_file_name)
      controller.generic_view_paths.find { |p| File.file?(File.join(p, template_file_name)) }
    end

    # We don't want to use generic_view_paths in ActionMailer, and we don't want
    # to use them unless the controller action was explicitly defined.
    def search_generic_view_paths?
      controller.respond_to?(:generic_view_paths) and controller.class.action_methods.include?(controller.action_name)
    end
  end
else # RAILS 2.1
  class ActionView::TemplateFinder
    def pick_template_with_generic_paths(template_path, extension)
      if @template.controller.class.uses_active_scaffold?
        path = pick_template_without_generic_paths(template_path, extension)
        return path if (path && ! path.empty?)
        template_file = File.basename(template_path)
        template_path = find_generic_base_path_for(template_file, extension)
        # ACC return absolute path to file
        template_path
      else
        pick_template_without_generic_paths(template_path, extension)
      end
    end
    alias_method_chain :pick_template, :generic_paths
    alias_method :template_exists?, :pick_template

    # Returns the view path that contains the relative template 
    def find_generic_base_path_for(template_file_name, extension)
      # ACC TODO use more robust method of setting this path
      path = RAILS_ROOT + '/vendor/plugins/active_scaffold/frontends/default/views'
      # Should be able to use a rails method here to do this directory search
      file = Dir.entries(path).find {|f| f =~ /^_?#{template_file_name}\.?#{extension}/ }
      file ? File.join(path, file) : nil
    end

    def find_template_extension_from_handler_with_generics(template_path, template_format = @template.template_format)
      t_ext = find_template_extension_from_handler_without_generics(template_path, template_format)
      if t_ext && !t_ext.empty?
        t_ext
      else
        'rhtml'
      end
    end
    alias_method_chain :find_template_extension_from_handler, :generics
  end
end
