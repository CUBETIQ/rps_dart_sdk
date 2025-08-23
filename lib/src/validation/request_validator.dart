/// Request validation interfaces for the RPS SDK
///
/// This file defines the validation system that provides flexible
/// data transformation and validation capabilities with configurable
/// schemas and detailed error reporting.
library;

/// Abstract interface for request validators that validate input data
/// against configurable schemas and business rules
abstract class RequestValidator {
  ValidationResult validate(
    Map<String, dynamic> requestData,
    String requestType,
  );
  String get validatorType;
}

/// Result of request validation containing errors, warnings, and success status
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> context;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.context = const {},
  });

  /// Creates a successful validation result
  factory ValidationResult.success({
    List<String> warnings = const [],
    Map<String, dynamic> context = const {},
  }) {
    return ValidationResult(
      isValid: true,
      warnings: warnings,
      context: context,
    );
  }

  /// Creates a failed validation result
  factory ValidationResult.failure({
    required List<String> errors,
    List<String> warnings = const [],
    Map<String, dynamic> context = const {},
  }) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
      context: context,
    );
  }

  /// Whether there are any warnings
  bool get hasWarnings => warnings.isNotEmpty;

  /// Whether there are any errors
  bool get hasErrors => errors.isNotEmpty;

  /// Total number of issues (errors + warnings)
  int get issueCount => errors.length + warnings.length;

  /// Combines this result with another validation result
  ValidationResult combine(ValidationResult other) {
    return ValidationResult(
      isValid: isValid && other.isValid,
      errors: [...errors, ...other.errors],
      warnings: [...warnings, ...other.warnings],
      context: {...context, ...other.context},
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('ValidationResult(isValid: $isValid');

    if (hasErrors) {
      buffer.write(', errors: ${errors.length}');
    }

    if (hasWarnings) {
      buffer.write(', warnings: ${warnings.length}');
    }

    buffer.write(')');
    return buffer.toString();
  }
}

/// Exception thrown when validation fails
class ValidationException implements Exception {
  final ValidationResult validationResult;
  final String? requestType;

  const ValidationException(this.validationResult, {this.requestType});

  @override
  String toString() {
    final buffer = StringBuffer('ValidationException');
    if (requestType != null) {
      buffer.write(' for $requestType');
    }
    buffer.write(': ${validationResult.errors.join(', ')}');
    return buffer.toString();
  }
}

/// Schema definition for request validation
class ValidationSchema {
  final Set<String> requiredFields;
  final Map<String, Type> fieldTypes;
  final Map<String, List<ValidationRule>> fieldRules;
  final List<ValidationRule> globalRules;
  final Map<String, int> maxLengths;
  final Map<String, int> minLengths;
  final Map<String, RegExp> patterns;

  const ValidationSchema({
    this.requiredFields = const {},
    this.fieldTypes = const {},
    this.fieldRules = const {},
    this.globalRules = const [],
    this.maxLengths = const {},
    this.minLengths = const {},
    this.patterns = const {},
  });

  /// Creates a schema builder for fluent configuration
  static ValidationSchemaBuilder builder() => ValidationSchemaBuilder();
}

/// Builder for creating validation schemas
class ValidationSchemaBuilder {
  final Set<String> _requiredFields = {};
  final Map<String, Type> _fieldTypes = {};
  final Map<String, List<ValidationRule>> _fieldRules = {};
  final List<ValidationRule> _globalRules = [];
  final Map<String, int> _maxLengths = {};
  final Map<String, int> _minLengths = {};
  final Map<String, RegExp> _patterns = {};

  /// Adds a required field
  ValidationSchemaBuilder requireField(String fieldName) {
    _requiredFields.add(fieldName);
    return this;
  }

  /// Sets the expected type for a field
  ValidationSchemaBuilder fieldType(String fieldName, Type type) {
    _fieldTypes[fieldName] = type;
    return this;
  }

  /// Adds a validation rule for a specific field
  ValidationSchemaBuilder fieldRule(String fieldName, ValidationRule rule) {
    _fieldRules.putIfAbsent(fieldName, () => []).add(rule);
    return this;
  }

  /// Adds a global validation rule
  ValidationSchemaBuilder globalRule(ValidationRule rule) {
    _globalRules.add(rule);
    return this;
  }

  /// Sets maximum length for a string field
  ValidationSchemaBuilder maxLength(String fieldName, int length) {
    _maxLengths[fieldName] = length;
    return this;
  }

  /// Sets minimum length for a string field
  ValidationSchemaBuilder minLength(String fieldName, int length) {
    _minLengths[fieldName] = length;
    return this;
  }

  /// Sets pattern validation for a string field
  ValidationSchemaBuilder pattern(String fieldName, RegExp pattern) {
    _patterns[fieldName] = pattern;
    return this;
  }

  /// Builds the validation schema
  ValidationSchema build() {
    return ValidationSchema(
      requiredFields: Set.from(_requiredFields),
      fieldTypes: Map.from(_fieldTypes),
      fieldRules: Map.from(_fieldRules),
      globalRules: List.from(_globalRules),
      maxLengths: Map.from(_maxLengths),
      minLengths: Map.from(_minLengths),
      patterns: Map.from(_patterns),
    );
  }
}

/// Abstract validation rule interface
abstract class ValidationRule {
  String? validate(
    dynamic value,
    String fieldName,
    Map<String, dynamic> context,
  );
  String get description;
}

/// Default implementation of RequestValidator with schema support
class DefaultRequestValidator implements RequestValidator {
  final Map<String, ValidationSchema> _schemas;
  final ValidationSchema? _defaultSchema;

  @override
  String get validatorType => 'default';

  const DefaultRequestValidator({
    Map<String, ValidationSchema>? schemas,
    ValidationSchema? defaultSchema,
  }) : _schemas = schemas ?? const {},
       _defaultSchema = defaultSchema;

  @override
  ValidationResult validate(
    Map<String, dynamic> requestData,
    String requestType,
  ) {
    final schema = _schemas[requestType] ?? _defaultSchema;
    if (schema == null) {
      return ValidationResult.success();
    }

    final errors = <String>[];
    final warnings = <String>[];
    final context = <String, dynamic>{};

    // Validate required fields
    for (final field in schema.requiredFields) {
      if (!requestData.containsKey(field) || requestData[field] == null) {
        errors.add('Required field "$field" is missing');
      }
    }

    // Validate field types and constraints
    for (final entry in requestData.entries) {
      final fieldName = entry.key;
      final value = entry.value;

      final expectedType = schema.fieldTypes[fieldName];
      if (expectedType != null && !_isValidType(value, expectedType)) {
        errors.add(
          'Field "$fieldName" must be of type ${expectedType.toString()}',
        );
        continue;
      }

      if (value is String) {
        final maxLength = schema.maxLengths[fieldName];
        if (maxLength != null && value.length > maxLength) {
          errors.add(
            'Field "$fieldName" exceeds maximum length of $maxLength characters',
          );
        }

        final minLength = schema.minLengths[fieldName];
        if (minLength != null && value.length < minLength) {
          errors.add(
            'Field "$fieldName" is below minimum length of $minLength characters',
          );
        }

        // Pattern validation
        final pattern = schema.patterns[fieldName];
        if (pattern != null && !pattern.hasMatch(value)) {
          errors.add('Field "$fieldName" does not match required pattern');
        }
      }

      final fieldRules = schema.fieldRules[fieldName];
      if (fieldRules != null) {
        for (final rule in fieldRules) {
          final error = rule.validate(value, fieldName, requestData);
          if (error != null) {
            errors.add(error);
          }
        }
      }
    }

    for (final rule in schema.globalRules) {
      final error = rule.validate(requestData, 'request', requestData);
      if (error != null) {
        errors.add(error);
      }
    }

    context['validatedFields'] = requestData.keys.toList();
    context['schemaType'] = requestType;

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      context: context,
    );
  }

  /// Checks if a value matches the expected type
  bool _isValidType(dynamic value, Type expectedType) {
    switch (expectedType) {
      case String:
        return value is String;
      case int:
        return value is int;
      case double:
        return value is double || value is int;
      case bool:
        return value is bool;
      case List:
        return value is List;
      case Map:
        return value is Map;
      default:
        return value.runtimeType == expectedType;
    }
  }
}

class CompositeRequestValidator implements RequestValidator {
  final List<RequestValidator> _validators;

  @override
  String get validatorType => 'composite';

  const CompositeRequestValidator(this._validators);

  @override
  ValidationResult validate(
    Map<String, dynamic> requestData,
    String requestType,
  ) {
    ValidationResult result = ValidationResult.success();

    for (final validator in _validators) {
      final validatorResult = validator.validate(requestData, requestType);
      result = result.combine(validatorResult);
    }

    return result;
  }
}

class ValidationRules {
  /// Validates that a numeric value is within a range
  static ValidationRule range(num min, num max) {
    return _RangeValidationRule(min, max);
  }

  /// Validates that a string is not empty
  static ValidationRule notEmpty() {
    return _NotEmptyValidationRule();
  }

  /// Validates that a value is in a list of allowed values
  static ValidationRule oneOf(List<dynamic> allowedValues) {
    return _OneOfValidationRule(allowedValues);
  }

  /// Validates email format
  static ValidationRule email() {
    return _EmailValidationRule();
  }

  /// Custom validation rule with a function
  static ValidationRule custom(
    String? Function(
      dynamic value,
      String fieldName,
      Map<String, dynamic> context,
    )?
    validator,
    String description,
  ) {
    return _CustomValidationRule(validator, description);
  }
}

class _RangeValidationRule implements ValidationRule {
  final num min;
  final num max;

  const _RangeValidationRule(this.min, this.max);

  @override
  String get description => 'Value must be between $min and $max';

  @override
  String? validate(
    dynamic value,
    String fieldName,
    Map<String, dynamic> context,
  ) {
    if (value is! num) {
      return 'Field "$fieldName" must be a number for range validation';
    }

    if (value < min || value > max) {
      return 'Field "$fieldName" must be between $min and $max';
    }

    return null;
  }
}

class _NotEmptyValidationRule implements ValidationRule {
  @override
  String get description => 'Value must not be empty';

  @override
  String? validate(
    dynamic value,
    String fieldName,
    Map<String, dynamic> context,
  ) {
    if (value is String && value.trim().isEmpty) {
      return 'Field "$fieldName" cannot be empty';
    }

    if (value is List && value.isEmpty) {
      return 'Field "$fieldName" cannot be empty';
    }

    if (value is Map && value.isEmpty) {
      return 'Field "$fieldName" cannot be empty';
    }

    return null;
  }
}

class _OneOfValidationRule implements ValidationRule {
  final List<dynamic> allowedValues;

  const _OneOfValidationRule(this.allowedValues);

  @override
  String get description => 'Value must be one of: ${allowedValues.join(', ')}';

  @override
  String? validate(
    dynamic value,
    String fieldName,
    Map<String, dynamic> context,
  ) {
    if (!allowedValues.contains(value)) {
      return 'Field "$fieldName" must be one of: ${allowedValues.join(', ')}';
    }

    return null;
  }
}

class _EmailValidationRule implements ValidationRule {
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  String get description => 'Value must be a valid email address';

  @override
  String? validate(
    dynamic value,
    String fieldName,
    Map<String, dynamic> context,
  ) {
    if (value is! String) {
      return 'Field "$fieldName" must be a string for email validation';
    }

    if (!_emailRegex.hasMatch(value)) {
      return 'Field "$fieldName" must be a valid email address';
    }

    return null;
  }
}

class _CustomValidationRule implements ValidationRule {
  final String? Function(
    dynamic value,
    String fieldName,
    Map<String, dynamic> context,
  )?
  _validator;
  final String _description;

  const _CustomValidationRule(this._validator, this._description);

  @override
  String get description => _description;

  @override
  String? validate(
    dynamic value,
    String fieldName,
    Map<String, dynamic> context,
  ) {
    return _validator?.call(value, fieldName, context);
  }
}
