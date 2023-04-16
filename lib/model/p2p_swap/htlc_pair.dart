class HtlcPair {
  final String hashLock;
  final String initialHtlcId;
  String preimage;
  String counterHtlcId;

  HtlcPair({
    required this.hashLock,
    required this.initialHtlcId,
    required this.preimage,
    required this.counterHtlcId,
  });

  HtlcPair.fromJson(Map<String, dynamic> json)
      : hashLock = json['hashLock'],
        initialHtlcId = json['initialHtlcId'],
        preimage = json['preimage'],
        counterHtlcId = json['counterHtlcId'];

  Map<String, dynamic> toJson() => {
        'hashLock': hashLock,
        'initialHtlcId': initialHtlcId,
        'preimage': preimage,
        'counterHtlcId': counterHtlcId,
      };
}
