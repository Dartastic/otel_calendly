// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_calendly/otel_calendly.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_calendly-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('scheduled_events.list records kind + status + tier', () async {
    await tracedCalendly<String>(
      operation: 'scheduled_events.list',
      organizationUri: 'https://api.calendly.com/organizations/abc',
      invoke: () async => const CalendlyCallResult(
        value: 'ok',
        result: CalendlyResult(
          itemCount: 20,
          nextPagePresent: true,
          eventKind: 'round_robin',
          status: 'active',
          tier: 'teams',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('calendly scheduled_events.list')!);
    expect(a['calendly.organization.uri'],
        'https://api.calendly.com/organizations/abc');
    expect(a['calendly.event.kind'], 'round_robin');
    expect(a['calendly.status'], 'active');
    expect(a['calendly.tier'], 'teams');
    expect(a['calendly.pagination.next_page.present'], true);
  });

  test('cancel records cancellation.reason', () async {
    await tracedCalendly<String>(
      operation: 'scheduled_events.cancel',
      invoke: () async => const CalendlyCallResult(
        value: 'ok',
        result: CalendlyResult(
          status: 'canceled',
          cancellationReason: 'invitee_canceled',
        ),
      ),
    );
    final a =
        attrsOf(spans.findSpanByName('calendly scheduled_events.cancel')!);
    expect(a['calendly.cancellation.reason'], 'invitee_canceled');
  });

  test('suppression skips spans', () async {
    await runWithoutCalendlyInstrumentationAsync(() async {
      await tracedCalendly<String>(
        operation: 'event_types.list',
        invoke: () async => const CalendlyCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('calendly '), isEmpty);
  });
}
