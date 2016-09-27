require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Renders the new lsit form
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
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Views a list
get '/lists/:number' do
  @list_id = params[:number].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Edit an existing list
get "/lists/:number/edit" do
  list_id = params[:number].to_i
  @list = session[:lists][list_id]
  erb :edit_list, layout: :layout
end

# Update an existing list
post '/lists/:number/edit' do
  list_name = params[:list_name].strip
  list_id = params[:number].to_i
  @list = session[:lists][list_id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists][list_id][:name] = list_name
    session[:success] = 'The list has been updated'
    redirect "/lists/#{list_id}"
  end
end

# Delete a given list
post '/lists/:number/destroy' do
  list_id = params[:number].to_i
  session[:lists].delete_at(list_id)
  session[:success] = "The list has been deleted"
  redirect '/lists'
end

# Deletes a doto from a list
post '/lists/:number/todos/:todo_index/destroy' do
  list_id = params[:number].to_i 
  todo_index = params[:todo_index].to_i
  session[:lists][list_id][:todos].delete_at(todo_index)   
  session[:success] = 'The todo has been deleted'
  redirect "/lists/#{list_id}"
end

# Add a new td to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  task = params[:todo].strip
  error = error_for_todo(task)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: task, completed: false } 
    session[:success] = 'The task has been added'
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a  td
post '/lists/:number/todos/:todo_index' do
  list_id = params[:number].to_i 
  todo_index = params[:todo_index].to_i
  is_completed = params[:completed] == 'true'
  session[:lists][list_id][:todos][todo_index][:completed] = is_completed
  session[:success] = 'The todo has been updated'
  redirect "/lists/#{list_id}"
end

# Completes all the tds in a list
post '/lists/:number/complete_all' do
  list_id = params[:number].to_i 
  session[:lists][list_id][:todos].each { |todo| todo[:completed] = true } 
  session[:success] = 'All the tasks have been completed'
  redirect "/lists/#{list_id}"
end

helpers do
  # Return an error message  if the name is invalid. Return nil if name is valid
  def error_for_list_name(name)
    if !(1..100).cover? name.size
      'The list name must be between 1 and 100 charachters'
    elsif session[:lists].any? { |list| list[:name] == name }
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
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end
