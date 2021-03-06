module TaggingPlugin
  module Hooks
    class LayoutHook < Redmine::Hook::ViewListener
      def view_issues_sidebar_planning_bottom(context={ })
        return '' if Setting.plugin_redmine_tagging[:sidebar_tagcloud] != "1"

        return context[:controller].send(:render_to_string, {
            :partial => 'tagging/tagcloud',
            :locals => context
          })
      end

      def view_issues_show_details_bottom(context={ })
        return '' if Setting.plugin_redmine_tagging[:issues_inline] == "1"

        issue = context[:issue]
        snippet = ''

        tag_context = issue.project.identifier.gsub('-', '_')

        tags = issue.tag_list_on(tag_context).sort.collect {|tag|
          link_to("#{tag}", {:controller => "search", :action => "index", :id => issue.project, :q => tag, :wiki_pages => true, :issues => true})
        }.join('&nbsp;')

        tags = "<tr><th>#{l(:field_tags)}:</th><td>#{tags}</td></tr>" if tags

        return tags
      end

      def view_issues_form_details_bottom(context={ })
        return '' if Setting.plugin_redmine_tagging[:issues_inline] == "1"

        issue = context[:issue]

        tag_context = issue.project.identifier.gsub('-', '_')

        tags = issue.tag_list_on(tag_context).sort.collect{|tag| tag.gsub(/^#/, '')}.join(' ')

        tags = '<p>' + context[:form].text_field(:tags, :value => tags) + '</p>'
        tags += javascript_include_tag 'jquery-1.4.2.min.js', :plugin => 'redmine_tagging'
        tags += javascript_include_tag 'tag.js', :plugin => 'redmine_tagging'

        ac = ActsAsTaggableOn::Tag.find(:all,
            :conditions => ["id in (select tag_id from taggings
            where taggable_type in ('WikiPage', 'Issue') and context = ?)", tag_context]).collect {|tag| tag.name}
        ac = ac.collect{|tag| "'#{escape_javascript(tag.gsub(/^#/, ''))}'"}.join(', ')
        tags += <<-generatedscript
          <script type="text/javascript">
            var $j = jQuery.noConflict();
            $j(document).ready(function() {
              $j('#issue_tags').tagSuggest({ tags: [#{ac}] });
            });
          </script>
        generatedscript

        return tags
      end

      def controller_issues_edit_after_save(context = {})
        return if Setting.plugin_redmine_tagging[:issues_inline] == "1"

        return unless context[:params] && context[:params]['issue']

        issue = context[:issue]
        tags = context[:params]['issue']['tags'].to_s

        tags = tags.split(/[#"'\s,]+/).collect{|tag| "##{tag}"}.join(', ')
        tag_context = issue.project.identifier.gsub('-', '_')

        issue.set_tag_list_on(tag_context, tags)
        issue.save
      end

      # wikis have no view hooks
      def view_layouts_base_content(context = {})
        return '' if Setting.plugin_redmine_tagging[:wiki_pages_inline] == "1"

        return '' unless context[:controller].is_a? WikiController

        request = context[:request]
        return '' unless request.parameters

        project = Project.find_by_identifier(request.parameters['id'])
        return '' unless project

        page = project.wiki.find_page(request.parameters['page'])
        return '' unless page

        tag_context = project.identifier.gsub('-', '_')
        tags = ''

        if request.parameters['action'] == 'index'
          tags = page.tag_list_on(tag_context).sort.collect {|tag|
            link_to("#{tag}", {:controller => "search", :action => "index", :id => project, :q => tag, :wiki_pages => true, :issues => true})
          }.join('&nbsp;')

          tags = "<h3>#{l(:field_tags)}:</h3><p>#{tags}</p>" if tags
        end

        if request.parameters['action'] == 'edit'
          tags = page.tag_list_on(tag_context).sort.collect{|tag| tag.gsub(/^#/, '')}.join(' ')
          tags = "<p id='tagging_wiki_edit_block'><label>#{l(:field_tags)}</label><br /><input id='wikipage_tags' name='wikipage_tags' size='120' type='text' value='#{h(tags)}'/></p>"

          ac = ActsAsTaggableOn::Tag.find(:all,
              :conditions => ["id in (select tag_id from taggings
              where taggable_type in ('WikiPage', 'Issue') and context = ?)", tag_context]).collect {|tag| tag.name}
          ac = ac.collect{|tag| "'#{escape_javascript(tag.gsub(/^#/, ''))}'"}.join(', ')

          tags += javascript_include_tag 'jquery-1.4.2.min.js', :plugin => 'redmine_tagging'
          tags += javascript_include_tag 'tag.js', :plugin => 'redmine_tagging'

          tags += <<-generatedscript
            <script type="text/javascript">
              var $j = jQuery.noConflict();
              $j(document).ready(function() {
                $j('#tagging_wiki_edit_block').insertAfter($j("#content_text").parent().parent());
                $j('#wikipage_tags').tagSuggest({ tags: [#{ac}] });
              });
            </script>
          generatedscript
        end

        return tags
      end

      def controller_wiki_edit_after_save(context = {})
        return if Setting.plugin_redmine_tagging[:wiki_pages_inline] == "1"

        return unless context[:params]

        project = context[:page].wiki.project

        tags = context[:params]['wikipage_tags'].to_s.split(/[#"'\s,]+/).collect{|tag| "##{tag}"}.join(', ')
        tag_context = project.identifier.gsub('-', '_')

        context[:page].set_tag_list_on(tag_context, tags)
        context[:page].save
      end

      def view_layouts_base_html_head(context = {})
        return "
          <style>
            span.tagMatches {
              margin-left: 10px;
            }
      
            span.tagMatches span {
              padding: 2px;
              margin-right: 4px;
              background-color: #0000AB;
              color: #fff;
              cursor: pointer;
            }
          </style>"
      end

    end
  end
end
