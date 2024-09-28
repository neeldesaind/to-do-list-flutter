import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() => runApp(TodoApp());

class TodoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo List App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TodoList(),
    );
  }
}

class Todo {
  final String mainTask;
  final String description;
  final DateTime createDate;
  DateTime dueDate;
  bool isCompleted;

  Todo({
    required this.mainTask,
    required this.description,
    required this.createDate,
    required this.dueDate,
    this.isCompleted = false,
  });

  Todo.fromJson(Map<String, dynamic> json)
      : mainTask = json['mainTask'],
        description = json['description'],
        createDate = DateTime.parse(json['createDate']),
        dueDate = DateTime.parse(json['dueDate']),
        isCompleted = json['isCompleted'];

  Map<String, dynamic> toJson() => {
    'mainTask': mainTask,
    'description': description,
    'createDate': createDate.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
    'isCompleted': isCompleted,
  };
}

class TodoList extends StatefulWidget {
  @override
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  Timer? _undoTimer;
  List<Todo> todos = [];
  TextEditingController mainTaskController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  DateTime? selectedDueDate;
  DateTime? selectedCreateDate;
  List<int> selectedIndexes = [];
  String? mainTaskError;
  String? descriptionError;
  int? editingIndex;
  String mainTaskCounterText = '0/7 characters';
  String descriptionCounterText = '0/50 characters';
  String selectedDrawerItem = 'Homepage';

  @override
  void initState() {
    super.initState();

    mainTaskController.addListener(updateMainTaskCount);
    descriptionController.addListener(updateDescriptionCount);

    _loadTodos();
  }

  _loadTodos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? todosJson = prefs.getString('todos');
    if (todosJson != null) {
      Iterable decoded = jsonDecode(todosJson);
      List<Todo> savedTodos =
      decoded.map((json) => Todo.fromJson(json)).toList();
      setState(() {
        todos = savedTodos;
      });
    }
  }

  _saveTodos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String todosJson = jsonEncode(todos);
    await prefs.setString('todos', todosJson);
  }

  void updateMainTaskCount() {
    setState(() {
      mainTaskCounterText = '${mainTaskController.text.length}/${7} characters';
      mainTaskError = null;
    });
  }

  void updateDescriptionCount() {
    setState(() {
      descriptionCounterText = '${descriptionController.text.length}/${50} characters';
      descriptionError = null;
    });
  }

  void _addTodo() {
    // Check if task name is empty
    if (mainTaskController.text.isEmpty) {
      setState(() {
        mainTaskError = 'Task name cannot be empty';
      });
      return;
    }

    // Check if task name already exists
    for (var i = 0; i < todos.length; i++) {
      if (editingIndex != null && editingIndex == i) {
        continue; // Skip current todo if it's being edited
      }
      if (todos[i].mainTask == mainTaskController.text) {
        setState(() {
          mainTaskError = 'Task name already exists';
        });
        return;
      }
    }

    if (mainTaskController.text.isNotEmpty &&
        descriptionController.text.isNotEmpty &&
        selectedDueDate != null) {
      setState(() {
        if (editingIndex != null) {
          todos[editingIndex!] = Todo(
            mainTask: mainTaskController.text,
            description: descriptionController.text,
            createDate: selectedCreateDate ?? DateTime.now(),
            dueDate: selectedDueDate!,
            isCompleted: todos[editingIndex!].isCompleted,
          );
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Todo updated successfully'),
          ));
        } else {
          todos.add(
            Todo(
              mainTask: mainTaskController.text,
              description: descriptionController.text,
              createDate: selectedCreateDate ?? DateTime.now(),
              dueDate: selectedDueDate!,
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Todo added successfully'),
          ));
        }
        mainTaskController.clear();
        descriptionController.clear();
        selectedDueDate = null;
        selectedCreateDate = null;
        mainTaskError = null;
        descriptionError = null;
        editingIndex = null;
        _saveTodos();
      });
    } else {
      setState(() {
        mainTaskError =
        mainTaskController.text.isEmpty ? 'Task field is required' : null;
        descriptionError = descriptionController.text.isEmpty
            ? 'Description field is required'
            : null;
      });
    }
  }


  void _toggleCompleted(int index) {
    setState(() {
      todos[index].isCompleted = !todos[index].isCompleted;
      // If task is marked as completed, set remaining days to 0
      if (todos[index].isCompleted) {
        todos[index].dueDate = DateTime.now();
      }
      _saveTodos();
    });
  }

  void _markAsCompleted() {
    setState(() {
      for (var index in selectedIndexes) {
        todos[index].isCompleted = true;
      }
      selectedIndexes.clear();
      _saveTodos();
    });
  }

  void _undoCompleted() {
    setState(() {
      for (var index in selectedIndexes) {
        todos[index].isCompleted = false;
      }
      selectedIndexes.clear();
      _saveTodos();
    });

    // Show Snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Undo done'),
      ),
    );
    _startUndoTimer();
  }
  void _startUndoTimer() {
    // Cancel previous timer if it exists
    _undoTimer?.cancel();

    // Start a new timer to disable undo after 60 seconds
    _undoTimer = Timer(Duration(seconds: 5), () {
      setState(() {
        // Clear selected indexes after 60 seconds
        selectedIndexes.clear();
      });
    });
  }
  void _editTodo(int index) {
    setState(() {
      if (editingIndex == index) {
        editingIndex = null; // Reset editingIndex if it's already editing the selected todo
        mainTaskController.clear(); // Clear text fields
        descriptionController.clear();
        selectedDueDate = null; // Reset selected dates
        selectedCreateDate = null;
      } else {
        mainTaskController.text = todos[index].mainTask;
        descriptionController.text = todos[index].description;
        selectedDueDate = todos[index].dueDate;
        selectedCreateDate = todos[index].createDate;
        editingIndex = index;
      }
    });
  }





  void _deleteTodoDialog(int index) {
    if (editingIndex == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Confirm Deletion'),
            content: Text('Are you sure you want to delete this task?'),
            actions: <Widget>[
              TextButton(
                child: Text('CANCEL'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('DELETE'),
                onPressed: () {
                  _deleteTodo(index);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Todo deleted successfully'),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _deleteTodo(int index) {
    setState(() {
      todos.removeAt(index);
      _saveTodos();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedCreateDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != selectedDueDate) {
      setState(() {
        if (picked.isBefore(DateTime.now())) {
          mainTaskError = 'Due date cannot be earlier than current date';
        } else if (selectedCreateDate != null &&
            picked.isBefore(selectedCreateDate!)) {
          mainTaskError = 'Due date cannot be earlier than create date';
        } else {
          // Calculate remaining days based on the picked date
          final remainingDays = picked.difference(DateTime.now()).inDays;
          // Set the selected due date and clear any error message
          selectedDueDate = picked;
          mainTaskError = null;
          _sortByPriority(); // Sort todos based on priority
        }
      });
    }
  }


  Future<void> _selectCreateDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (picked != null) {
      setState(() {
        selectedCreateDate = picked;
      });
    }
  }

  String _calculateRemainingDays(DateTime dueDate) {
    final today = DateTime.now();
    final difference = dueDate.difference(today).inDays;
    return difference.toString();
  }
  String _calculateRemainingTime(DateTime dueDate) {
    final today = DateTime.now();
    final difference = dueDate.difference(today);
    if (difference.inDays <= 0) {
      // If due date has passed or is today, calculate remaining hours
      final remainingHours = difference.inHours;
      return remainingHours == 1 ? '$remainingHours hour' : '$remainingHours hours';
    } else {
      // If due date is in the future, calculate remaining days
      final remainingDays = difference.inDays;
      return remainingDays == 1 ? '$remainingDays day' : '$remainingDays days';
    }
  }


  Color _getColorFromInitials(String initials) {
    List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.pink,
    ];

    int hashCode = initials.codeUnitAt(0) % colors.length;
    return colors[hashCode];
  }
  void _sortByPriority() {
    setState(() {
      todos.sort((a, b) {
        // Calculate remaining days for each task
        final remainingDaysA = int.tryParse(_calculateRemainingDays(a.dueDate)) ?? 0;
        final remainingDaysB = int.tryParse(_calculateRemainingDays(b.dueDate)) ?? 0;

        // Compare remaining days
        if (remainingDaysA < remainingDaysB) {
          return -1; // Task A has fewer remaining days, so it comes first
        } else if (remainingDaysA > remainingDaysB) {
          return 1; // Task B has fewer remaining days, so it comes first
        }

        // If remaining days are equal, prioritize incomplete tasks over completed tasks
        if (!a.isCompleted && b.isCompleted) {
          return -1; // Task A is incomplete, so it comes first
        } else if (a.isCompleted && !b.isCompleted) {
          return 1; // Task B is incomplete, so it comes first
        }

        // If remaining days and completion status are the same, maintain the current order
        return 0;
      });
    });
  }





  @override
  Widget build(BuildContext context) {
    _sortByPriority();
    return Scaffold(
      appBar: AppBar(
        title: Text('Todo List'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('assets/case_logo.jpg'),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'TO DO LIST',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Homepage'),
              selected: selectedDrawerItem == 'Homepage',
              onTap: () {
                setState(() {
                  selectedDrawerItem = 'Homepage';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('About Us'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AboutUsPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text('Exit App'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("Confirm Exit"),
                      content: Text("Are you sure you want to exit the app?"),
                      actions: <Widget>[
                        TextButton(
                          child: Text("Cancel"),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: Text("Exit"),
                          onPressed: () {
                            // Exit app
                            SystemNavigator.pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),

          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: mainTaskController,
                maxLength: 7,
                decoration: InputDecoration(
                  labelText: 'Task',
                  counterText: mainTaskCounterText,
                  border: OutlineInputBorder(),
                  errorText: mainTaskError,
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                controller: descriptionController,
                maxLines: null,
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: 'Description',
                  counterText: descriptionCounterText,
                  border: OutlineInputBorder(),
                  errorText: descriptionError,
                ),
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create Date: ${selectedCreateDate?.toLocal().toString().split(' ')[0] ?? DateTime.now().toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () => _selectCreateDate(context),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.grey[200],
                        side: BorderSide(color: Colors.grey.shade300, width: 1.0),
                      ),
                      child: Text('Select Create Date'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDueDate != null
                          ? 'Due Date: ${selectedDueDate!.toLocal().toString().split(' ')[0]}'
                          : 'Select Due Date',
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () => _selectDate(context),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.grey[200],
                        side: BorderSide(color: Colors.grey.shade300, width: 1.0),
                      ),
                      child: Text('Select Finish Date'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _addTodo,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: editingIndex != null ? Colors.green : Colors.pinkAccent[200], // Change color to green if editingIndex is not null
                  side: BorderSide(color: Colors.grey.shade300, width: 1.0),
                  textStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                child: Text(editingIndex != null ? 'Update Todo' : 'Add Todo'),
              ),

              SizedBox(height: 16.0),
              ListView.builder(
                shrinkWrap: true,
                itemCount: todos.length,
                itemBuilder: (context, index) {
                  final remainingDays = _calculateRemainingDays(todos[index].dueDate);
                  final remainingDaysInt = int.tryParse(remainingDays);
                  final isOverdue = remainingDaysInt != null && remainingDaysInt <= 2;

                  return SingleChildScrollView(
                    child: Card(
                      child: ListTile(
                        title: Text(
                          todos[index].mainTask,
                          style: TextStyle(
                            decoration: todos[index].isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                            fontWeight: FontWeight.bold,
                            fontSize: 18, // Adjust font size as needed
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Description: ${todos[index].description}',
                              style: TextStyle(fontSize: 16), // Adjust font size as needed
                            ),
                            Text(
                              'Start Date: ${todos[index].createDate.toLocal().toString().split(' ')[0]}',
                              style: TextStyle(fontSize: 14), // Adjust font size as needed
                            ),
                            Text(
                              'End Date: ${todos[index].dueDate.toLocal().toString().split(' ')[0]}',
                              style: TextStyle(fontSize: 14), // Adjust font size as needed
                            ),
                            Text(
                              'Remaining Days: ${_calculateRemainingDays(todos[index].dueDate)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: todos[index].isCompleted ? Colors.grey : (isOverdue ? Colors.red : Colors.black),
                              ),
                            ),
                            Text(
                              'Remaining Time: ${_calculateRemainingTime(todos[index].dueDate)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: todos[index].isCompleted ? Colors.grey : (isOverdue ? Colors.red : Colors.black),
                              ),
                            ),
                            Text(
                              'Status: ${todos[index].isCompleted ? 'Completed' : 'Incomplete'}', // Add status text
                              style: TextStyle(
                                fontSize: 14,
                                color: todos[index].isCompleted ? Colors.green : Colors.red, // Change color based on completion status
                              ),
                            ),
                          ],
                        ),
                        contentPadding: EdgeInsets.all(16.0),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            todos[index].isCompleted
                                ? IconButton(
                              icon: Icon(Icons.undo, color: Colors.pink,),
                              onPressed: () {
                                _undoCompleted();
                                _toggleCompleted(index);
                              },
                            )
                                : Checkbox(
                              value: selectedIndexes.contains(index),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value ?? false) {
                                    selectedIndexes.add(index);
                                  } else {
                                    selectedIndexes.remove(index);
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: todos[index].isCompleted ? Colors.grey : Colors.green),
                              onPressed: todos[index].isCompleted ? null : () => _editTodo(index),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: selectedIndexes.contains(index) ? Colors.grey : (editingIndex == index ? Colors.grey : Colors.red)),
                              onPressed: selectedIndexes.contains(index) ? null : () => _deleteTodoDialog(index),
                            ),

                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16.0),
              if (selectedIndexes.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    _markAsCompleted();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Completed'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                  ),
                  child: Text('Mark as Completed'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AboutUsPage extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('About Us'),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Card(
              elevation: 4.0,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage('assets/neel_avatar.jpg'), // You can replace this with the actual image path
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      'Neel Desai',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Student at CHARUSAT',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      'Organization: TECHPRENUER',
                      style: TextStyle(
                        fontSize: 18.0,
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      'Email: neel.desai1653@gmail.com',
                      style: TextStyle(
                        fontSize: 18.0,
                      ),
                    ),
                    Text(
                      'Contact: +91 81600 26509',
                      style: TextStyle(
                        fontSize: 18.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}
