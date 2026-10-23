// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_calendly/otel_calendly.dart';

/// Traces Calendly v2 calls with OpenTelemetry.
///
/// `otel_calendly` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Calendly v2 call in
/// [tracedCalendly]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'calendly-example');

  // Wraps a Calendly v2 call in a CLIENT span.
  final calendlyId = await tracedCalendly<String>(
    operation: 'invitee_no_shows.create',
    organizationUri: 'example',
    invoke: () async {
      // Make the Calendly v2 call here, then report what it returned.
      const id = 'calendly_8f3a2c';
      return const CalendlyCallResult(
          value: id,
          result: CalendlyResult(
              itemCount: 3,
              nextPagePresent: true,
              eventKind: 'solo',
              status: 'active',
              cancellationReason: 'canceler_type',
              reschedule: true,
              tier: 'essentials',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedCalendly invitee_no_shows.create returned $calendlyId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutCalendlyInstrumentationAsync.
  await runWithoutCalendlyInstrumentationAsync(
    () => tracedCalendly<String>(
      operation: 'invitee_no_shows.create',
      organizationUri: 'example',
      invoke: () async {
        const id = 'calendly_8f3a2c';
        return const CalendlyCallResult(
            value: id,
            result: CalendlyResult(
                itemCount: 3,
                nextPagePresent: true,
                eventKind: 'solo',
                status: 'active',
                cancellationReason: 'canceler_type',
                reschedule: true,
                tier: 'essentials',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
