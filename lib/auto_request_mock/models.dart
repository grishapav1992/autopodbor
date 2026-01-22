import 'package:flutter/material.dart';

enum RequestType { byCar, turnkey }

enum RequestStatus {
  draft,
  published,
  hasOffers,
  proSelected,
  inProgress,
  completed,
  cancelled,
  dispute,
}

class CarItem {
  CarItem({
    required this.id,
    this.make = '',
    this.model = '',
    this.restyling = '',
    this.year = '',
    this.vin = '',
    this.plate = '',
    this.sourceUrl = '',
    this.sellerPhone = '',
    this.note = '',
  });

  final String id;
  String make;
  String model;
  String restyling;
  String year;
  String vin;
  String plate;
  String sourceUrl;
  String sellerPhone;
  String note;

  CarItem copy() => CarItem(
        id: id,
        make: make,
        model: model,
        restyling: restyling,
        year: year,
        vin: vin,
        plate: plate,
        sourceUrl: sourceUrl,
        sellerPhone: sellerPhone,
        note: note,
      );
}

class TurnkeyFilters {
  TurnkeyFilters({
    required this.makes,
    required this.models,
    required this.versions,
    required this.segmentScheme,
    required this.segments,
    this.yearFrom,
    this.yearTo,
    this.mileageFrom,
    this.mileageTo,
    required this.bodyTypes,
    required this.fuelTypes,
    required this.transmissions,
    required this.drives,
    this.ownersMax,
    this.noAccidents,
    this.serviceBookRequired,
    required this.colorPreferences,
    this.mustHave,
    this.mustAvoid,
  });

  final List<String> makes;
  final List<String> models;
  final List<String> versions;

  final String segmentScheme;
  final List<String> segments;

  final int? yearFrom;
  final int? yearTo;

  final int? mileageFrom;
  final int? mileageTo;

  final List<String> bodyTypes;
  final List<String> fuelTypes;
  final List<String> transmissions;
  final List<String> drives;

  final int? ownersMax;
  final bool? noAccidents;
  final bool? serviceBookRequired;
  final List<String> colorPreferences;

  final String? mustHave;
  final String? mustAvoid;
}

class AutoRequest {
  AutoRequest({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.status,
    required this.city,
    this.budgetFromRub,
    this.budgetToRub,
    this.comment,
    this.cars,
    this.turnkey,
    this.reportCount,
  });

  final String id;
  final DateTime createdAt;
  final RequestType type;
  RequestStatus status;

  String city;
  int? budgetFromRub;
  int? budgetToRub;
  String? comment;

  List<CarItem>? cars;
  TurnkeyFilters? turnkey;

  int? reportCount;
}

class ProProfile {
  ProProfile({
    required this.id,
    required this.name,
    required this.city,
    required this.rating,
    required this.completedDeals,
    required this.yearsExp,
    required this.about,
  });

  final String id;
  final String name;
  final String city;
  final int rating;
  final int completedDeals;
  final int yearsExp;
  final String about;
}

class ProOffer {
  ProOffer({
    required this.id,
    required this.requestId,
    required this.proId,
    required this.priceRub,
    required this.etaDays,
    this.message,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String proId;
  final int priceRub;
  final int etaDays;
  final String? message;
  final DateTime createdAt;
}

class UiTokens {
  const UiTokens({
    required this.gray900,
    required this.gray700,
    required this.gray600,
    required this.gray400,
    required this.gray300,
    required this.gray100,
    required this.gray50,
    required this.blue600,
    required this.red600,
    required this.red100,
    required this.red200,
  });

  final Color gray900;
  final Color gray700;
  final Color gray600;
  final Color gray400;
  final Color gray300;
  final Color gray100;
  final Color gray50;
  final Color blue600;
  final Color red600;
  final Color red100;
  final Color red200;
}
