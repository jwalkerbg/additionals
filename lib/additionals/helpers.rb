# Global helper functions
module Additionals
  module Helpers
    def additionals_library_load(module_name)
      method = "additionals_load_#{module_name}"
      send(method)
    end

    def system_uptime
      if windows_platform?
        `net stats srv | find "Statist"`
      elsif File.exist?('/proc/uptime')
        secs = `cat /proc/uptime`.to_i
        min = 0
        hours = 0
        days = 0
        if secs > 0
          min = (secs / 60).round
          hours = (secs / 3_600).round
          days = (secs / 86_400).round
        end
        if days >= 1
          "#{days} #{l(:days, count: days)}"
        elsif hours >= 1
          "#{hours} #{l(:hours, count: hours)}"
        else
          "#{min} #{l(:minutes, count: min)}"
        end
      else
        days = `uptime | awk '{print $3}'`.to_i.round
        "#{days} #{l(:days, count: days)}"
      end
    end

    def system_info
      if windows_platform?
        'unknown'
      else
        `uname -a`
      end
    end

    def windows_platform?
      true if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
    end

    def memberbox_view_roles
      view_roles = []
      @users_by_role.keys.sort.each do |role|
        if !role.permissions.include?(:hide_in_memberbox) ||
           (role.permissions.include?(:hide_in_memberbox) && User.current.allowed_to?(:show_hidden_roles_in_memberbox, @project))
          view_roles << role
        end
      end
      view_roles
    end

    def add_top_menu_custom_item(i, user_roles)
      menu_name = 'custom_menu' + i.to_s
      item = {
        url: Setting.plugin_additionals[menu_name + '_url'],
        name: Setting.plugin_additionals[menu_name + '_name'],
        title: Setting.plugin_additionals[menu_name + '_title'],
        roles: Setting.plugin_additionals[menu_name + '_roles']
      }
      return if item[:name].blank? || item[:url].blank? || item[:roles].nil?

      show_entry = false
      item[:roles].each do |role|
        if user_roles.empty? && role.to_i == Role::BUILTIN_ANONYMOUS
          show_entry = true
          break
        elsif User.current.logged? && role.to_i == Role::BUILTIN_NON_MEMBER
          # if user is logged in and non_member is active in item,
          # always show it
          show_entry = true
          break
        end

        user_roles.each do |user_role|
          if role.to_i == user_role.id.to_i
            show_entry = true
            break
          end
        end
        break if show_entry == true
      end
      handle_top_menu_item(menu_name, item, show_entry)
    end

    def handle_top_menu_item(menu_name, item, show_entry = false)
      if Redmine::MenuManager.map(:top_menu).exists?(menu_name.to_sym)
        Redmine::MenuManager.map(:top_menu).delete(menu_name.to_sym)
      end
      return unless show_entry

      html_options = {}
      html_options[:class] = 'external' if item[:url].include? '://'
      html_options[:title] = item[:title] if item[:title].present?
      Redmine::MenuManager.map(:top_menu).push menu_name,
                                               item[:url],
                                               caption: item[:name].to_s,
                                               html: html_options,
                                               before: :help
    end

    def bootstrap_datepicker_locale
      s = ''
      locale = User.current.language.blank? ? ::I18n.locale : User.current.language
      s = javascript_include_tag("locales/bootstrap-datepicker.#{locale}.min", plugin: 'additionals') unless locale == 'en'
      s
    end


    private

    def cl_already_loaded(scope, js)
      locked = "#{js}.#{scope}"
      @alreaded_loaded = [] if @alreaded_loaded.nil?
      return true if @alreaded_loaded.include?(locked)
      @alreaded_loaded << locked
      false
    end

    def cl_include_js(js)
      if cl_already_loaded('js', js)
        ''
      else
        javascript_include_tag(js, plugin: 'common_libraries') + "\n"
      end
    end

    def cl_include_css(css)
      if cl_already_loaded('css', css)
        ''
      else
        stylesheet_link_tag(css, plugin: 'common_libraries') + "\n"
      end
    end

    def additionals_load_font_awesome
      cl_include_css('font-awesome.min')
    end

    def additionals_load_angular_gantt
      cl_include_css('angular-gantt.min') +
        cl_include_css('angular-gantt-plugins.min') +
        cl_include_css('angular-ui-tree.min') +
        cl_include_js('moment-with-locales.min') +
        cl_include_js('angular.min') +
        cl_include_js('angular-moment.min') +
        cl_include_js('angular-ui-tree.min') +
        cl_include_js('angular-gantt.min') +
        cl_include_js('angular-gantt-plugins.min')
    end

    def additionals_load_nvd3
      cl_include_css('nv.d3.min') +
        cl_include_js('d3.min') +
        cl_include_js('nv.d3.min')
    end

    def additionals_load_d3plus
      cl_include_js('d3.min') +
        cl_include_js('d3plus.min')
    end

    def additionals_load_tooltips
      cl_include_css('tooltips') +
        cl_include_js('tooltips')
    end

    def additionals_load_bootstrap
      cl_include_css('bootstrap.min') +
        cl_include_js('bootstrap.min')
    end

    def additionals_load_bootstrap_theme
      cl_include_css('bootstrap.min') +
        cl_include_css('bootstrap-theme.min') +
        cl_include_js('bootstrap.min')
    end

    def additionals_load_tag_it
      cl_include_css('jquery.tagit') +
        cl_include_js('tag-it')
    end

    def additionals_load_zeroclipboard
      cl_include_js('zeroclipboard_min')
    end

    def font_awesome_get_from_info
      s = []
      s << l(:label_set_icon_from)
      s << link_to('http://fontawesome.io/icons/', 'http://fontawesome.io/icons/', class: 'external')
      safe_join(s, ' ')
    end

    def user_with_avatar(user, size = 14)
      return if user.nil?
      s = []
      s << avatar(user, size: size)
      s << link_to_user(user)
      safe_join(s)
    end

    def query_default_sort(query, fall_back_sort)
      criteria = query.sort_criteria.any? ? query.sort_criteria : fall_back_sort
      return unless criteria.is_a?(Array)
      sql = []
      criteria.each do |sort|
        name = sort[0]
        field = []
        field << query.queried_class.table_name if name == 'name'
        field << name
        sql << "#{field.join('.')} #{sort[1].upcase}"
      end
      sql.join(', ')
    end

    def options_for_overview_select(active)
      options_for_select({ l(:button_hide) => '',
                           l(:show_on_redmine_home) => 'home',
                           l(:show_on_project_overview) => 'project',
                           l(:show_always) => 'always' }, active)
    end

    def options_for_welcome_select(active)
      options_for_select({ l(:button_hide) => '',
                           l(:show_welcome_left) => 'left',
                           l(:show_welcome_right) => 'right' }, active)
    end

    def human_float_number(value, sep = '.')
      ActionController::Base.helpers.number_with_precision(value,
                                                           precision: 2,
                                                           separator: sep,
                                                           strip_insignificant_zeros: true)
    end
  end
end

ActionView::Base.send :include, Additionals::Helpers