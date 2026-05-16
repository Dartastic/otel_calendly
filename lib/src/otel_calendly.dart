// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_calendly_suppression.dart';

const _tracerName = 'dartastic_otel_libs_calendly';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class CalendlyResult {
  const CalendlyResult({
    this.itemCount,
    this.nextPagePresent,
    this.eventKind,
    this.status,
    this.cancellationReason,
    this.reschedule,
    this.tier,
    this.requestId,
    this.statusCode,
  });

  /// `collection.length` for list endpoints.
  final int? itemCount;

  /// `pagination.next_page` present.
  final bool? nextPagePresent;

  /// `solo` / `group` / `collective` / `round_robin`.
  final String? eventKind;

  /// `active` / `canceled` for scheduled events; `active` / `removed`
  /// for invitees.
  final String? status;

  /// Set when the event was canceled — `canceler_type` + reason.
  final String? cancellationReason;

  /// `reschedule_url` produced for an invitee.
  final bool? reschedule;

  /// Workspace plan: `essentials` / `professional` / `teams` /
  /// `enterprise` (some endpoints are tier-gated).
  final String? tier;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class CalendlyCallResult<T> {
  const CalendlyCallResult({required this.value, this.result});
  final T value;
  final CalendlyResult? result;
}

/// Wraps a Calendly v2 call in a CLIENT span. [operation] is one of
/// `event_types.list`, `event_types.get`, `scheduled_events.list`,
/// `scheduled_events.get`, `scheduled_events.cancel`, `invitees.list`,
/// `invitees.get`, `invitee_no_shows.create`,
/// `invitee_no_shows.delete`, `webhook_subscriptions.create`,
/// `webhook_subscriptions.delete`, `organization_memberships.list`,
/// `routing_forms.list`, `data_compliance.delete`.
Future<T> tracedCalendly<T>({
  required String operation,
  required Future<CalendlyCallResult<T>> Function() invoke,
  String? organizationUri,
}) async {
  if (calendlyInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'calendly',
    'rpc.method': operation,
    'calendly.operation': operation,
  };
  if (organizationUri != null) {
    m['calendly.organization.uri'] = organizationUri;
  }

  final span = _tracer().startSpan(
    'calendly $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'calendly.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.nextPagePresent != null) {
        extras.add(OTel.attributeBool(
          'calendly.pagination.next_page.present',
          r.result!.nextPagePresent!,
        ));
      }
      if (r.result!.eventKind != null) {
        extras.add(OTel.attributeString(
          'calendly.event.kind',
          r.result!.eventKind!,
        ));
      }
      if (r.result!.status != null) {
        extras.add(OTel.attributeString(
          'calendly.status',
          r.result!.status!,
        ));
      }
      if (r.result!.cancellationReason != null) {
        extras.add(OTel.attributeString(
          'calendly.cancellation.reason',
          r.result!.cancellationReason!,
        ));
      }
      if (r.result!.reschedule != null) {
        extras.add(OTel.attributeBool(
          'calendly.invitee.rescheduled',
          r.result!.reschedule!,
        ));
      }
      if (r.result!.tier != null) {
        extras.add(OTel.attributeString(
          'calendly.tier',
          r.result!.tier!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'calendly.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Calendly HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
