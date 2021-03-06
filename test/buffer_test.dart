// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'package:test/test.dart';

import 'package:stream_transform/stream_transform.dart';

void main() {
  var streamTypes = {
    'single subscription': () => new StreamController(),
    'broadcast': () => new StreamController.broadcast()
  };
  for (var triggerType in streamTypes.keys) {
    for (var valuesType in streamTypes.keys) {
      group('Trigger type: [$triggerType], Values type: [$valuesType]', () {
        StreamController trigger;
        StreamController values;
        List emittedValues;
        bool valuesCanceled;
        bool triggerCanceled;
        bool isDone;
        List errors;
        StreamSubscription subscription;

        setUp(() async {
          valuesCanceled = false;
          triggerCanceled = false;
          trigger = streamTypes[triggerType]()
            ..onCancel = () {
              triggerCanceled = true;
            };
          values = streamTypes[triggerType]()
            ..onCancel = () {
              valuesCanceled = true;
            };
          emittedValues = [];
          errors = [];
          isDone = false;
          subscription = values.stream
              .transform(buffer(trigger.stream))
              .listen(emittedValues.add, onError: errors.add, onDone: () {
            isDone = true;
          });
        });

        test('does not emit before `trigger`', () async {
          values.add(1);
          await new Future(() {});
          expect(emittedValues, isEmpty);
          trigger.add(null);
          await new Future(() {});
          expect(emittedValues, [
            [1]
          ]);
        });

        test('emits immediately if trigger emits before a value', () async {
          trigger.add(null);
          await new Future(() {});
          expect(emittedValues, isEmpty);
          values.add(1);
          await new Future(() {});
          expect(emittedValues, [
            [1]
          ]);
        });

        test('two triggers in a row - emit then emit next value', () async {
          values.add(1);
          values.add(2);
          await new Future(() {});
          trigger.add(null);
          trigger.add(null);
          await new Future(() {});
          values.add(3);
          await new Future(() {});
          expect(emittedValues, [
            [1, 2],
            [3]
          ]);
        });

        test('pre-emptive trigger then trigger after values', () async {
          trigger.add(null);
          await new Future(() {});
          values.add(1);
          values.add(2);
          await new Future(() {});
          trigger.add(null);
          await new Future(() {});
          expect(emittedValues, [
            [1],
            [2]
          ]);
        });

        test('multiple pre-emptive triggers, only emits first value', () async {
          trigger.add(null);
          trigger.add(null);
          await new Future(() {});
          values.add(1);
          values.add(2);
          await new Future(() {});
          expect(emittedValues, [
            [1]
          ]);
        });

        test('groups values between trigger', () async {
          values.add(1);
          values.add(2);
          await new Future(() {});
          trigger.add(null);
          values.add(3);
          values.add(4);
          await new Future(() {});
          trigger.add(null);
          await new Future(() {});
          expect(emittedValues, [
            [1, 2],
            [3, 4]
          ]);
        });

        test('cancels value subscription when output canceled', () async {
          expect(valuesCanceled, false);
          await subscription.cancel();
          expect(valuesCanceled, true);
        });

        test('cancels trigger subscription when output canceled', () async {
          expect(triggerCanceled, false);
          await subscription.cancel();
          expect(triggerCanceled, true);
        });

        test('closes when trigger ends', () async {
          expect(isDone, false);
          await trigger.close();
          await new Future(() {});
          expect(isDone, true);
        });

        test('closes after outputting final values when source closes',
            () async {
          expect(isDone, false);
          values.add(1);
          await values.close();
          expect(isDone, false);
          trigger.add(null);
          await new Future(() {});
          expect(emittedValues, [
            [1]
          ]);
          expect(isDone, true);
        });

        test(
            'closes immediately if there are no pending values when source closes',
            () async {
          expect(isDone, false);
          values.add(1);
          trigger.add(null);
          await values.close();
          await new Future(() {});
          expect(isDone, true);
        });

        test('forwards errors from trigger', () async {
          trigger.addError('error');
          await new Future(() {});
          expect(errors, ['error']);
        });

        test('forwards errors from values', () async {
          values.addError('error');
          await new Future(() {});
          expect(errors, ['error']);
        });
      });
    }
  }
}
