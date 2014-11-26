# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../test_helper', __FILE__)

class JournalsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles, :issues, :journals, :journal_details, :enabled_modules,
    :trackers, :issue_statuses, :enumerations, :custom_fields, :custom_values, :custom_fields_projects

  def setup
    User.current = nil
  end

  def test_index
    get :index, :project_id => 1
    assert_response :success
    assert_not_nil assigns(:journals)
    assert_equal 'application/atom+xml', @response.content_type
  end

  def test_index_should_return_privates_notes_with_permission_only
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Privates notes', :private_notes => true, :user_id => 1)
    @request.session[:user_id] = 2

    get :index, :project_id => 1
    assert_response :success
    assert_include journal, assigns(:journals)

    Role.find(1).remove_permission! :view_private_notes
    get :index, :project_id => 1
    assert_response :success
    assert_not_include journal, assigns(:journals)
  end

  def test_diff
    get :diff, :id => 3, :detail_id => 4
    assert_response :success
    assert_template 'diff'

    assert_tag 'span',
      :attributes => {:class => 'diff_out'},
      :content => /removed/
    assert_tag 'span',
      :attributes => {:class => 'diff_in'},
      :content => /added/
  end

  def test_reply_to_issue
    @request.session[:user_id] = 2
    xhr :get, :new, :id => 6
    assert_response :success
    assert_template 'new'
    assert_equal 'text/javascript', response.content_type
    assert_include '> This is an issue', response.body
  end

  def test_reply_to_issue_without_permission
    @request.session[:user_id] = 7
    xhr :get, :new, :id => 6
    assert_response 403
  end

  def test_reply_to_note
    @request.session[:user_id] = 2
    xhr :get, :new, :id => 6, :journal_id => 4
    assert_response :success
    assert_template 'new'
    assert_equal 'text/javascript', response.content_type
    assert_include '> A comment with a private version', response.body
  end

  def test_reply_to_private_note_should_fail_without_permission
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Privates notes', :private_notes => true)
    @request.session[:user_id] = 2

    xhr :get, :new, :id => 2, :journal_id => journal.id
    assert_response :success
    assert_template 'new'
    assert_equal 'text/javascript', response.content_type
    assert_include '> Privates notes', response.body

    Role.find(1).remove_permission! :view_private_notes
    xhr :get, :new, :id => 2, :journal_id => journal.id
    assert_response 404
  end

  def test_edit_xhr
    @request.session[:user_id] = 1
    xhr :get, :edit, :id => 2
    assert_response :success
    assert_template 'edit'
    assert_equal 'text/javascript', response.content_type
    assert_include 'textarea', response.body
  end

  def test_edit_private_note_should_fail_without_permission
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Privates notes', :private_notes => true)
    @request.session[:user_id] = 2
    Role.find(1).add_permission! :edit_issue_notes

    xhr :get, :edit, :id => journal.id
    assert_response :success
    assert_template 'edit'
    assert_equal 'text/javascript', response.content_type
    assert_include 'textarea', response.body

    Role.find(1).remove_permission! :view_private_notes
    xhr :get, :edit, :id => journal.id
    assert_response 404
  end

  def test_update_xhr
    @request.session[:user_id] = 1
    xhr :post, :edit, :id => 2, :notes => 'Updated notes'
    assert_response :success
    assert_template 'update'
    assert_equal 'text/javascript', response.content_type
    assert_equal 'Updated notes', Journal.find(2).notes
    assert_include 'journal-2-notes', response.body
  end

  def test_update_xhr_with_empty_notes_should_delete_the_journal
    @request.session[:user_id] = 1
    assert_difference 'Journal.count', -1 do
      xhr :post, :edit, :id => 2, :notes => ''
      assert_response :success
      assert_template 'update'
      assert_equal 'text/javascript', response.content_type
    end
    assert_nil Journal.find_by_id(2)
    assert_include 'change-2', response.body
  end
end
