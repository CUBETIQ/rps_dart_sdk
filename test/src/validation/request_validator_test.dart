import 'package:test/test.dart';
import 'package:rps_dart_sdk/src/validation/request_validator.dart';

void main() {
  group('ValidationResult', () {
    test('should create successful result', () {
      final result = ValidationResult.success();

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.hasErrors, isFalse);
      expect(result.hasWarnings, isFalse);
      expect(result.issueCount, equals(0));
    });

    test('should create successful result with warnings', () {
      final result = ValidationResult.success(
        warnings: ['Warning message'],
        context: {'key': 'value'},
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first, equals('Warning message'));
      expect(result.hasWarnings, isTrue);
      expect(result.issueCount, equals(1));
      expect(result.context['key'], equals('value'));
    });

    test('should create failed result', () {
      final result = ValidationResult.failure(
        errors: ['Error 1', 'Error 2'],
        warnings: ['Warning'],
      );

      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(2));
      expect(result.warnings, hasLength(1));
      expect(result.hasErrors, isTrue);
      expect(result.hasWarnings, isTrue);
      expect(result.issueCount, equals(3));
    });

    test('should combine validation results', () {
      final result1 = ValidationResult.failure(
        errors: ['Error 1'],
        warnings: ['Warning 1'],
        context: {'key1': 'value1'},
      );

      final result2 = ValidationResult.failure(
        errors: ['Error 2'],
        warnings: ['Warning 2'],
        context: {'key2': 'value2'},
      );

      final combined = result1.combine(result2);

      expect(combined.isValid, isFalse);
      expect(combined.errors, hasLength(2));
      expect(combined.warnings, hasLength(2));
      expect(combined.context, containsPair('key1', 'value1'));
      expect(combined.context, containsPair('key2', 'value2'));
    });

    test('should combine valid and invalid results', () {
      final validResult = ValidationResult.success(warnings: ['Warning']);
      final invalidResult = ValidationResult.failure(errors: ['Error']);

      final combined = validResult.combine(invalidResult);

      expect(combined.isValid, isFalse);
      expect(combined.errors, hasLength(1));
      expect(combined.warnings, hasLength(1));
    });

    test('should have proper toString representation', () {
      final result = ValidationResult.failure(
        errors: ['Error'],
        warnings: ['Warning'],
      );

      final str = result.toString();
      expect(str, contains('ValidationResult'));
      expect(str, contains('isValid: false'));
      expect(str, contains('errors: 1'));
      expect(str, contains('warnings: 1'));
    });
  });

  group('ValidationException', () {
    test('should create exception with validation result', () {
      final result = ValidationResult.failure(errors: ['Test error']);
      final exception = ValidationException(result, requestType: 'invoice');

      expect(exception.validationResult, equals(result));
      expect(exception.requestType, equals('invoice'));
    });

    test('should have proper toString representation', () {
      final result = ValidationResult.failure(errors: ['Error 1', 'Error 2']);
      final exception = ValidationException(result, requestType: 'invoice');

      final str = exception.toString();
      expect(str, contains('ValidationException for invoice'));
      expect(str, contains('Error 1, Error 2'));
    });
  });

  group('ValidationSchema', () {
    test('should create empty schema', () {
      const schema = ValidationSchema();

      expect(schema.requiredFields, isEmpty);
      expect(schema.fieldTypes, isEmpty);
      expect(schema.fieldRules, isEmpty);
      expect(schema.globalRules, isEmpty);
    });

    test('should create schema with builder', () {
      final schema = ValidationSchema.builder()
          .requireField('name')
          .requireField('email')
          .fieldType('name', String)
          .fieldType('age', int)
          .maxLength('name', 100)
          .minLength('name', 2)
          .pattern('email', RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'))
          .fieldRule('age', ValidationRules.range(0, 120))
          .globalRule(
            ValidationRules.custom(
              (value, field, context) => null,
              'Custom global rule',
            ),
          )
          .build();

      expect(schema.requiredFields, containsAll(['name', 'email']));
      expect(schema.fieldTypes['name'], equals(String));
      expect(schema.fieldTypes['age'], equals(int));
      expect(schema.maxLengths['name'], equals(100));
      expect(schema.minLengths['name'], equals(2));
      expect(schema.patterns['email'], isA<RegExp>());
      expect(schema.fieldRules['age'], hasLength(1));
      expect(schema.globalRules, hasLength(1));
    });
  });

  group('DefaultRequestValidator', () {
    late DefaultRequestValidator validator;

    setUp(() {
      final schema = ValidationSchema.builder()
          .requireField('name')
          .requireField('email')
          .fieldType('name', String)
          .fieldType('age', int)
          .fieldType('active', bool)
          .maxLength('name', 50)
          .minLength('name', 2)
          .pattern('email', RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'))
          .fieldRule('age', ValidationRules.range(0, 120))
          .fieldRule('name', ValidationRules.notEmpty())
          .build();

      validator = DefaultRequestValidator(schemas: {'user': schema});
    });

    test('should validate valid request successfully', () {
      final requestData = {
        'name': 'John Doe',
        'email': 'john@example.com',
        'age': 30,
        'active': true,
      };

      final result = validator.validate(requestData, 'user');

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.context['validatedFields'], contains('name'));
      expect(result.context['schemaType'], equals('user'));
    });

    test('should fail validation for missing required fields', () {
      final requestData = {'age': 30};

      final result = validator.validate(requestData, 'user');

      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(2));
      expect(result.errors, contains('Required field "name" is missing'));
      expect(result.errors, contains('Required field "email" is missing'));
    });

    test('should fail validation for wrong field types', () {
      final requestData = {
        'name': 123, // Should be String
        'email': 'john@example.com',
        'age': 'thirty', // Should be int
        'active': 'yes', // Should be bool
      };

      final result = validator.validate(requestData, 'user');

      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(3));
      expect(
        result.errors.any((e) => e.contains('name') && e.contains('String')),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.contains('age') && e.contains('int')),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.contains('active') && e.contains('bool')),
        isTrue,
      );
    });

    test('should fail validation for string length constraints', () {
      final requestData = {
        'name': 'A', // Too short (min 2)
        'email': 'john@example.com',
      };

      final result = validator.validate(requestData, 'user');

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('minimum length')), isTrue);
    });

    test('should fail validation for pattern mismatch', () {
      final requestData = {
        'name': 'John Doe',
        'email': 'invalid-email', // Doesn't match email pattern
      };

      final result = validator.validate(requestData, 'user');

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('email') && e.contains('pattern')),
        isTrue,
      );
    });

    test('should fail validation for custom field rules', () {
      final requestData = {
        'name': 'John Doe',
        'email': 'john@example.com',
        'age': 150, // Outside range 0-120
      };

      final result = validator.validate(requestData, 'user');

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('age') && e.contains('between')),
        isTrue,
      );
    });

    test('should pass validation for unknown request type', () {
      final requestData = {'anything': 'goes'};

      final result = validator.validate(requestData, 'unknown');

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('should accept int for double type', () {
      final schema = ValidationSchema.builder()
          .fieldType('price', double)
          .build();

      final validator = DefaultRequestValidator(schemas: {'product': schema});

      final requestData = {'price': 10}; // int value for double field

      final result = validator.validate(requestData, 'product');

      expect(result.isValid, isTrue);
    });
  });

  group('CompositeRequestValidator', () {
    test('should combine results from multiple validators', () {
      final validator1 = _MockValidator([
        ValidationResult.failure(errors: ['Error 1']),
      ]);

      final validator2 = _MockValidator([
        ValidationResult.failure(errors: ['Error 2'], warnings: ['Warning 1']),
      ]);

      final composite = CompositeRequestValidator([validator1, validator2]);

      final result = composite.validate({'test': 'data'}, 'test');

      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(2));
      expect(result.warnings, hasLength(1));
      expect(result.errors, contains('Error 1'));
      expect(result.errors, contains('Error 2'));
      expect(result.warnings, contains('Warning 1'));
    });

    test('should return valid result when all validators pass', () {
      final validator1 = _MockValidator([ValidationResult.success()]);
      final validator2 = _MockValidator([ValidationResult.success()]);

      final composite = CompositeRequestValidator([validator1, validator2]);

      final result = composite.validate({'test': 'data'}, 'test');

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });
  });

  group('ValidationRules', () {
    group('range', () {
      test('should validate numeric values within range', () {
        final rule = ValidationRules.range(1, 10);

        expect(rule.validate(5, 'field', {}), isNull);
        expect(rule.validate(1, 'field', {}), isNull);
        expect(rule.validate(10, 'field', {}), isNull);
      });

      test('should fail for values outside range', () {
        final rule = ValidationRules.range(1, 10);

        expect(rule.validate(0, 'field', {}), isNotNull);
        expect(rule.validate(11, 'field', {}), isNotNull);
      });

      test('should fail for non-numeric values', () {
        final rule = ValidationRules.range(1, 10);

        expect(rule.validate('5', 'field', {}), isNotNull);
      });
    });

    group('notEmpty', () {
      test('should validate non-empty values', () {
        final rule = ValidationRules.notEmpty();

        expect(rule.validate('hello', 'field', {}), isNull);
        expect(rule.validate([1, 2, 3], 'field', {}), isNull);
        expect(rule.validate({'key': 'value'}, 'field', {}), isNull);
      });

      test('should fail for empty values', () {
        final rule = ValidationRules.notEmpty();

        expect(rule.validate('', 'field', {}), isNotNull);
        expect(rule.validate('   ', 'field', {}), isNotNull);
        expect(rule.validate([], 'field', {}), isNotNull);
        expect(rule.validate({}, 'field', {}), isNotNull);
      });
    });

    group('oneOf', () {
      test('should validate values in allowed list', () {
        final rule = ValidationRules.oneOf(['red', 'green', 'blue']);

        expect(rule.validate('red', 'field', {}), isNull);
        expect(rule.validate('green', 'field', {}), isNull);
        expect(rule.validate('blue', 'field', {}), isNull);
      });

      test('should fail for values not in allowed list', () {
        final rule = ValidationRules.oneOf(['red', 'green', 'blue']);

        expect(rule.validate('yellow', 'field', {}), isNotNull);
        expect(rule.validate('purple', 'field', {}), isNotNull);
      });
    });

    group('email', () {
      test('should validate correct email addresses', () {
        final rule = ValidationRules.email();

        expect(rule.validate('test@example.com', 'field', {}), isNull);
        expect(rule.validate('user.name@domain.co.uk', 'field', {}), isNull);
        expect(rule.validate('user+tag@example.org', 'field', {}), isNull);
      });

      test('should fail for invalid email addresses', () {
        final rule = ValidationRules.email();

        expect(rule.validate('invalid-email', 'field', {}), isNotNull);
        expect(rule.validate('@example.com', 'field', {}), isNotNull);
        expect(rule.validate('test@', 'field', {}), isNotNull);
        expect(rule.validate('test.example.com', 'field', {}), isNotNull);
      });

      test('should fail for non-string values', () {
        final rule = ValidationRules.email();

        expect(rule.validate(123, 'field', {}), isNotNull);
      });
    });

    group('custom', () {
      test('should use custom validation function', () {
        final rule = ValidationRules.custom((value, field, context) {
          if (value is String && value.startsWith('test_')) {
            return null;
          }
          return 'Value must start with "test_"';
        }, 'Custom test rule');

        expect(rule.validate('test_value', 'field', {}), isNull);
        expect(rule.validate('other_value', 'field', {}), isNotNull);
        expect(rule.description, equals('Custom test rule'));
      });

      test('should handle null validator function', () {
        final rule = ValidationRules.custom(null, 'Null validator');

        expect(rule.validate('anything', 'field', {}), isNull);
      });
    });
  });
}

/// Mock validator for testing composite validator
class _MockValidator implements RequestValidator {
  final List<ValidationResult> _results;
  int _callCount = 0;

  _MockValidator(this._results);

  @override
  String get validatorType => 'mock';

  @override
  ValidationResult validate(
    Map<String, dynamic> requestData,
    String requestType,
  ) {
    if (_callCount < _results.length) {
      return _results[_callCount++];
    }
    return ValidationResult.success();
  }
}
