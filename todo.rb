require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'

require_relative 'database_persistense'

configure do
  enable :sessions
  set :erb, :escape_html => true
end

configure (:development) do
  require 'sinatra/reloader'
  require 'pry';
  also_reload "database_persistense.rb"
end

before do
  @storage = DatabasePersistence.new(logger)
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Renders the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Creates a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Views a list
get '/lists/:number' do
  @list_id = params[:number].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit an existing list
get "/lists/:number/edit" do
  list_id = params[:number].to_i
  @list = load_list(list_id)
  erb :edit_list, layout: :layout
end

# Update an existing list
post '/lists/:number' do
  list_name = params[:list_name].strip
  list_id = params[:number].to_i
  @list = load_list(list_id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.update_list_name(list_id, list_name) 
    session[:success] = 'The list has been updated'
    redirect "/lists/#{list_id}"
  end
end

# Delete a given list
post '/lists/:number/destroy' do
  list_id = params[:number].to_i
  @storage.delete_list(list_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted"
    redirect '/lists'
  end
end

# Deletes a doto from a list
post '/lists/:number/todos/:todo_index/destroy' do
  list_id = params[:number].to_i 
  todo_index = params[:todo_index].to_i
  @storage.delete_todo_from_list(list_id, todo_index)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = 'The todo has been deleted'
    redirect "/lists/#{list_id}"
  end
end

# Add a new td to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  task = params[:todo].strip
  error = error_for_todo(task)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_todo(@list_id, task)
    session[:success] = 'The task has been added'
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a  td
post '/lists/:number/todos/:todo_index' do
  list_id = params[:number].to_i 
  todo_id = params[:todo_index].to_i
  is_completed = params[:completed] == 'true'

  @storage.update_todo_status(list_id, todo_id, is_completed)
  session[:success] = 'The todo has been updated'
  redirect "/lists/#{list_id}"
end

# Completes all the tds in a list
post '/lists/:number/complete_all' do
  list_id = params[:number].to_i 

  @storage.mark_all_todos_as_completed(list_id)

  session[:success] = 'All the tasks have been completed'
  redirect "/lists/#{list_id}"
end

helpers do
  # Return an error message  if the name is invalid. Return nil if name is valid
  def error_for_list_name(name)
    if !(1..100).cover? name.size
      'The list name must be between 1 and 100 charachters'
    elsif @storage.all_lists.any? { |list| list[:name] == name }
      "There's already a list with that name"
    end
  end

  def error_for_todo(task)
    if !(1..200).cover? task.size
      'The task must be between 1 and 200 charachters'
    end
  end

  def complete_list?(list)
    todos = list[:todos]
    todos.any? && todos.all? { |todo| todo[:completed] }
  end

  def complete_count(list)
    todos = list[:todos]
    todos.count { |todo| todo[:completed] }
  end

  def list_class(list)
    'complete' if complete_list?(list)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| complete_list?(list) }
    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end
  
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end

  def load_list(id)
    list = @storage.find_list(id)
    return list if list
    
    session[:error] = 'The specified list was not found'
    redirect '/lists'
  end
end
