// Unit tests for circuit breaker pattern used in audio operations
// Tests the failure threshold, cooldown, and recovery behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:myna/config/audio_config.dart';

/// Simulates the circuit breaker pattern used in MynaAudioHandler
class CircuitBreakerSimulator {
  int _consecutiveFailures = 0;
  DateTime? _circuitOpenedAt;

  bool get isOpen =>
      _consecutiveFailures >= AudioConfig.circuitBreakerFailureThreshold &&
      _circuitOpenedAt != null &&
      DateTime.now().difference(_circuitOpenedAt!) <
          AudioConfig.circuitBreakerResetTimeout;

  bool get isClosed => !isOpen;

  /// Record a failure. Returns true if circuit just opened.
  bool recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= AudioConfig.circuitBreakerFailureThreshold) {
      _circuitOpenedAt = DateTime.now();
      return true; // Circuit just opened
    }
    return false;
  }

  /// Record a success. Resets the circuit.
  void recordSuccess() {
    _consecutiveFailures = 0;
    _circuitOpenedAt = null;
  }

  /// Check if we should allow an operation through.
  /// Returns true if circuit is closed OR if enough time has passed (half-open).
  bool shouldAllow({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    if (_consecutiveFailures < AudioConfig.circuitBreakerFailureThreshold) {
      return true; // Circuit closed
    }
    if (_circuitOpenedAt == null) {
      return true; // No open time recorded
    }
    // Check if cooldown has passed (half-open state)
    return currentTime.difference(_circuitOpenedAt!) >=
        AudioConfig.circuitBreakerResetTimeout;
  }

  // For testing: manually set the circuit opened time
  void setCircuitOpenedAt(DateTime time) {
    _circuitOpenedAt = time;
  }

  int get consecutiveFailures => _consecutiveFailures;
}

void main() {
  group('CircuitBreaker Config Constants', () {
    test('failure threshold is reasonable', () {
      // Should require multiple failures before opening
      expect(
          AudioConfig.circuitBreakerFailureThreshold, greaterThanOrEqualTo(2));
      // But not too many (would delay protection)
      expect(AudioConfig.circuitBreakerFailureThreshold, lessThanOrEqualTo(5));
      // Current value is 3
      expect(AudioConfig.circuitBreakerFailureThreshold, equals(3));
    });

    test('reset timeout is reasonable', () {
      // Should be long enough for transient issues to resolve
      expect(AudioConfig.circuitBreakerResetTimeout.inSeconds,
          greaterThanOrEqualTo(5));
      // But not so long user waits forever
      expect(AudioConfig.circuitBreakerResetTimeout.inSeconds,
          lessThanOrEqualTo(30));
      // Current value is 10s
      expect(AudioConfig.circuitBreakerResetTimeout.inSeconds, equals(10));
    });

    test('operation timeout prevents indefinite hangs', () {
      expect(
          AudioConfig.operationTimeout.inSeconds, greaterThanOrEqualTo(15));
      expect(AudioConfig.operationTimeout.inSeconds, lessThanOrEqualTo(120));
      // Current value is 60s (increased from 30s to handle slow networks)
      expect(AudioConfig.operationTimeout.inSeconds, equals(60));
    });
  });

  group('CircuitBreaker State Transitions', () {
    late CircuitBreakerSimulator breaker;

    setUp(() {
      breaker = CircuitBreakerSimulator();
    });

    test('starts in closed state', () {
      expect(breaker.isClosed, isTrue);
      expect(breaker.isOpen, isFalse);
      expect(breaker.shouldAllow(), isTrue);
      expect(breaker.consecutiveFailures, equals(0));
    });

    test('stays closed on single failure', () {
      breaker.recordFailure();

      expect(breaker.isClosed, isTrue);
      expect(breaker.shouldAllow(), isTrue);
      expect(breaker.consecutiveFailures, equals(1));
    });

    test('stays closed below threshold', () {
      // Record failures up to threshold - 1
      for (var i = 0;
          i < AudioConfig.circuitBreakerFailureThreshold - 1;
          i++) {
        breaker.recordFailure();
      }

      expect(breaker.isClosed, isTrue);
      expect(breaker.shouldAllow(), isTrue);
      expect(breaker.consecutiveFailures,
          equals(AudioConfig.circuitBreakerFailureThreshold - 1));
    });

    test('opens at failure threshold', () {
      // Record exactly threshold failures
      for (var i = 0; i < AudioConfig.circuitBreakerFailureThreshold; i++) {
        final opened = breaker.recordFailure();
        if (i == AudioConfig.circuitBreakerFailureThreshold - 1) {
          expect(opened, isTrue, reason: 'Should open on threshold failure');
        } else {
          expect(opened, isFalse, reason: 'Should not open before threshold');
        }
      }

      expect(breaker.isOpen, isTrue);
      expect(breaker.isClosed, isFalse);
      expect(breaker.consecutiveFailures,
          equals(AudioConfig.circuitBreakerFailureThreshold));
    });

    test('blocks operations when open', () {
      // Open the circuit
      for (var i = 0; i < AudioConfig.circuitBreakerFailureThreshold; i++) {
        breaker.recordFailure();
      }

      // Immediately after opening, should block
      expect(breaker.shouldAllow(), isFalse);
    });

    test('allows operation after cooldown (half-open state)', () {
      // Open the circuit
      for (var i = 0; i < AudioConfig.circuitBreakerFailureThreshold; i++) {
        breaker.recordFailure();
      }

      // Set the opened time to past the cooldown
      final pastCooldown = DateTime.now()
          .subtract(AudioConfig.circuitBreakerResetTimeout)
          .subtract(const Duration(seconds: 1));
      breaker.setCircuitOpenedAt(pastCooldown);

      // Should allow in half-open state
      expect(breaker.shouldAllow(), isTrue);
    });

    test('success resets circuit to closed', () {
      // Open the circuit
      for (var i = 0; i < AudioConfig.circuitBreakerFailureThreshold; i++) {
        breaker.recordFailure();
      }
      expect(breaker.isOpen, isTrue);

      // Record success
      breaker.recordSuccess();

      // Should be fully closed
      expect(breaker.isClosed, isTrue);
      expect(breaker.consecutiveFailures, equals(0));
      expect(breaker.shouldAllow(), isTrue);
    });

    test('success in half-open state closes circuit', () {
      // Open the circuit
      for (var i = 0; i < AudioConfig.circuitBreakerFailureThreshold; i++) {
        breaker.recordFailure();
      }

      // Simulate cooldown passed
      final pastCooldown = DateTime.now()
          .subtract(AudioConfig.circuitBreakerResetTimeout)
          .subtract(const Duration(seconds: 1));
      breaker.setCircuitOpenedAt(pastCooldown);

      // Operation allowed in half-open
      expect(breaker.shouldAllow(), isTrue);

      // Success closes circuit
      breaker.recordSuccess();

      expect(breaker.isClosed, isTrue);
      expect(breaker.consecutiveFailures, equals(0));
    });

    test('failure after success starts count from 1', () {
      // One failure
      breaker.recordFailure();
      expect(breaker.consecutiveFailures, equals(1));

      // Success resets
      breaker.recordSuccess();
      expect(breaker.consecutiveFailures, equals(0));

      // New failure starts from 1
      breaker.recordFailure();
      expect(breaker.consecutiveFailures, equals(1));
    });
  });

  group('CircuitBreaker Timing Scenarios', () {
    test('remains open during cooldown period', () {
      final breaker = CircuitBreakerSimulator();

      // Open the circuit
      for (var i = 0; i < AudioConfig.circuitBreakerFailureThreshold; i++) {
        breaker.recordFailure();
      }

      final now = DateTime.now();

      // Set opened time to 1 second ago - should still be blocking (cooldown is 10s)
      breaker.setCircuitOpenedAt(now.subtract(const Duration(seconds: 1)));
      expect(breaker.shouldAllow(now: now), isFalse,
          reason: 'Should block 1s into 10s cooldown');

      // Set opened time to 5 seconds ago - should still be blocking
      breaker.setCircuitOpenedAt(now.subtract(const Duration(seconds: 5)));
      expect(breaker.shouldAllow(now: now), isFalse,
          reason: 'Should block 5s into 10s cooldown');

      // Set opened time to 9 seconds ago - should still be blocking
      breaker.setCircuitOpenedAt(now.subtract(const Duration(seconds: 9)));
      expect(breaker.shouldAllow(now: now), isFalse,
          reason: 'Should block 9s into 10s cooldown');
    });

    test('transitions to half-open exactly at cooldown', () {
      final breaker = CircuitBreakerSimulator();

      // Open the circuit
      for (var i = 0; i < AudioConfig.circuitBreakerFailureThreshold; i++) {
        breaker.recordFailure();
      }

      final now = DateTime.now();

      // Set opened time to exactly cooldown duration ago
      breaker.setCircuitOpenedAt(
          now.subtract(AudioConfig.circuitBreakerResetTimeout));

      // Should be allowed (half-open)
      expect(breaker.shouldAllow(now: now), isTrue);
    });
  });

  group('CircuitBreaker Integration Scenario', () {
    test('simulates real audio operation failure pattern', () {
      final breaker = CircuitBreakerSimulator();
      int operationAttempts = 0;
      int operationsBlocked = 0;

      Future<bool> simulateOperation({required bool willFail}) async {
        if (!breaker.shouldAllow()) {
          operationsBlocked++;
          return false; // Fast fail
        }

        operationAttempts++;

        // Simulate operation
        if (willFail) {
          breaker.recordFailure();
          return false;
        } else {
          breaker.recordSuccess();
          return true;
        }
      }

      // First few operations fail (simulating network issues)
      for (var i = 0; i < AudioConfig.circuitBreakerFailureThreshold; i++) {
        simulateOperation(willFail: true);
      }

      expect(operationAttempts,
          equals(AudioConfig.circuitBreakerFailureThreshold));
      expect(breaker.isOpen, isTrue);

      // Next few operations are blocked (fast fail)
      for (var i = 0; i < 5; i++) {
        simulateOperation(willFail: true);
      }

      expect(operationsBlocked, equals(5));
      expect(operationAttempts,
          equals(AudioConfig.circuitBreakerFailureThreshold));

      // After cooldown, operation is allowed
      breaker.setCircuitOpenedAt(DateTime.now()
          .subtract(AudioConfig.circuitBreakerResetTimeout)
          .subtract(const Duration(seconds: 1)));

      // Successful operation resets circuit
      simulateOperation(willFail: false);

      expect(breaker.isClosed, isTrue);
      expect(operationAttempts,
          equals(AudioConfig.circuitBreakerFailureThreshold + 1));
    });
  });
}
