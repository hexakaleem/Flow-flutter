import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TaskService {
  static const _kTasksKey = 'driver_tasks';

  Future<List<Task>> getTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTasksKey);
    if (raw == null || raw.isEmpty) return [];

    final list = json.decode(raw) as List;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<bool> addTask(Task task) async {
    final tasks = await getTasks();
    tasks.insert(0, task);
    return await _saveTasks(tasks);
  }

  Future<bool> updateTask(Task task) async {
    final tasks = await getTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return false;
    tasks[index] = task;
    return await _saveTasks(tasks);
  }

  Future<bool> deleteTask(String id) async {
    final tasks = await getTasks();
    final filtered = tasks.where((t) => t.id != id).toList();
    return await _saveTasks(filtered);
  }

  Future<bool> _saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final list = tasks.map((t) => t.toJson()).toList();
    return await prefs.setString(_kTasksKey, json.encode(list));
  }
}
