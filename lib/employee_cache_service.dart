// employee_cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeCacheService {
  static const String cacheKey = 'cached_employees';
  static const String lastUpdateKey = 'employees_last_update';

  /// Sauvegarde la liste des employés en cache local
  static Future<void> cacheEmployees(List<dynamic> employees) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeesJson = jsonEncode(employees);
      await prefs.setString(cacheKey, employeesJson);
      await prefs.setInt(lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Gérer l'erreur silencieusement en production
    }
  }

  /// Récupère la liste des employés depuis le cache local
  static Future<List<dynamic>> getCachedEmployees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeesJson = prefs.getString(cacheKey);
      
      if (employeesJson == null) return [];
      
      final employees = jsonDecode(employeesJson);
      return employees is List ? employees : [];
    } catch (e) {
      // Retourner une liste vide en cas d'erreur
      return [];
    }
  }

  /// Vérifie si le cache est récent (moins de 5 minutes)
  static Future<bool> isCacheRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(lastUpdateKey);
      
      if (lastUpdate == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - lastUpdate;
      const fiveMinutes = 5 * 60 * 1000; // 5 minutes en millisecondes
      
      return diff < fiveMinutes;
    } catch (e) {
      return false;
    }
  }

  /// Ajoute un employé au cache local
  static Future<void> addEmployeeToCache(Map<String, dynamic> employee) async {
    try {
      final employees = await getCachedEmployees();
      employees.add(employee);
      await cacheEmployees(employees);
    } catch (e) {
      // Gérer l'erreur silencieusement
    }
  }

  /// Met à jour un employé dans le cache local
  static Future<void> updateEmployeeInCache(String employeeId, Map<String, dynamic> updatedEmployee) async {
    try {
      final employees = await getCachedEmployees();
      final index = employees.indexWhere((emp) => emp['_id'] == employeeId);
      
      if (index != -1) {
        employees[index] = updatedEmployee;
        await cacheEmployees(employees);
      }
    } catch (e) {
      // Gérer l'erreur silencieusement
    }
  }

  /// Supprime un employé du cache local
  static Future<void> removeEmployeeFromCache(String employeeId) async {
    try {
      final employees = await getCachedEmployees();
      employees.removeWhere((emp) => emp['_id'] == employeeId);
      await cacheEmployees(employees);
    } catch (e) {
      // Gérer l'erreur silencieusement
    }
  }

  /// Vide le cache des employés
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
      await prefs.remove(lastUpdateKey);
    } catch (e) {
      // Gérer l'erreur silencieusement
    }
  }

  /// Synchronise le cache avec les données du serveur
  static Future<List<dynamic>> syncWithServer(List<dynamic> serverEmployees) async {
    try {
      await cacheEmployees(serverEmployees);
      return serverEmployees;
    } catch (e) {
      // En cas d'erreur, retourner le cache existant
      return await getCachedEmployees();
    }
  }
}