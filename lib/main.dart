import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Todo List',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Or any other color scheme
        useMaterial3: true,
      ),
      home: const TodoListScreen(),
      debugShowCheckedModeBanner: false, // Optional: Removes the debug banner
    );
  }
}

// --- TodoListScreen Widget (Stateful) ---
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  // --- State Variables ---
  final List<TodoItem> _todos = []; // List to hold our todo items
  final TextEditingController _textFieldController = TextEditingController();

  // --- Methods ---
  void _addTodoItem(String title) {
    // Only add if the title is not empty
    if (title.trim().isNotEmpty) {
      setState(() {
        // Use setState to update the UI
        _todos.add(TodoItem(title: title.trim()));
      });
      _textFieldController.clear(); // Clear the text field
      Navigator.of(context).pop(); // Close the dialog
    }
  }

  void _toggleTodoStatus(int index) {
    setState(() {
      _todos[index].isDone = !_todos[index].isDone;
    });
  }

  void _deleteTodoItem(int index) {
    setState(() {
      _todos.removeAt(index);
    });
  }

  // --- Dialog for adding new todos ---
  Future<void> _displayAddDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // Allow closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add a new todo item'),
          content: TextField(
            controller: _textFieldController,
            decoration: const InputDecoration(hintText: 'Enter todo title'),
            autofocus: true, // Automatically focus the text field
            onSubmitted: (value) => _addTodoItem(value), // Add on Enter key
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                _textFieldController.clear(); // Clear if cancelled
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                _addTodoItem(_textFieldController.text);
              },
            ),
          ],
        );
      },
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        itemCount: _todos.length,
        itemBuilder: (context, index) {
          final todo = _todos[index];
          return ListTile(
            leading: Checkbox(
              value: todo.isDone,
              onChanged: (bool? value) {
                _toggleTodoStatus(index);
              },
            ),
            title: Text(
              todo.title,
              style: TextStyle(
                decoration:
                    todo.isDone
                        ? TextDecoration
                            .lineThrough // Strikethrough if done
                        : TextDecoration.none,
                color: todo.isDone ? Colors.grey : null, // Grey out if done
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _deleteTodoItem(index),
              tooltip: 'Delete Item',
            ),
            onTap: () => _toggleTodoStatus(index), // Toggle status on tap too
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _displayAddDialog, // Show the add dialog on press
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Dispose the controller when the widget is removed from the tree
  @override
  void dispose() {
    _textFieldController.dispose();
    super.dispose();
  }
}

// --- TodoItem Model Class ---
class TodoItem {
  String title;
  bool isDone;

  TodoItem({required this.title, this.isDone = false});
}
