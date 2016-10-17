require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: 'todolist')
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1"
    result = query(sql, id)

    tuple = result.first # The result object behaves as if there were multiple rows

    list_id = tuple['id'].to_i
    todos = find_todos_for_list(list_id)
    { id: list_id, name: tuple['name'], todos: todos }
  end

  def all_lists
    result = query('SELECT * FROM lists')
    result.map do |list_tuple|
      list_id = list_tuple['id'].to_i
      todos = find_todos_for_list(list_id)

      { id: list_tuple['id'], name: list_tuple['name'], todos: todos }
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(list_id)
    query("DELETE FROM todos WHERE list_id = $1", list_id)
    query("DELETE FROM lists WHERE id = $1", list_id)
  end

  def update_list_name(id, new_name)
    query("UPDATE lists SET name = $1 WHERE id = $2", new_name, id)
  end

  def create_todo(list_id, todo_name)
    query("INSERT INTO todos (name, list_id) VALUES ($1, $2)", todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    query("DELETE FROM todos WHERE id = $1 AND list_id = $2", todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    query("UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3", new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    binding.pry
    query("UPDATE todos SET completed = 't' WHERE list_id = $1", list_id)
  end

  private

  def find_todos_for_list(list_id)
    todos_result = query("SELECT * FROM todos WHERE list_id = $1", list_id)

    todos = todos_result.map do |todo_tuple|
      { 
        id: todo_tuple['id'].to_i,
        name: todo_tuple['name'],
        completed: todo_tuple['completed'] == 't'
      }
    end
  end
end
