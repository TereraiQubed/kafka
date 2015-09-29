part of kafka;

/// FetchRequest as defined in Kafka protocol spec.
///
/// This is a low-level API object and requires good knowledge of Kafka protocol.
/// Consider using high-level [KafkaConsumer] class instead.
///
/// ### Some important information extracted from Kafka protocol spec:
///
/// * Fetch requests follow a long poll model so they can be made to block for
///   a period of time if sufficient data is not immediately available.
/// * As an optimization the server is allowed to return a partial message at
///   the end of the message set. Clients should handle this case.
class FetchRequest extends KafkaRequest {
  /// API key of [FetchRequest]
  final int apiKey = 1;

  /// API version of [FetchRequest]
  final int apiVersion = 0;

  /// The replica id indicates the node id of the replica initiating this request.
  /// Normal client consumers should always specify this as -1 as they have no node id.
  final int _replicaId = -1;

  /// Maximum amount of time in milliseconds to block waiting if insufficient
  /// data is available at the time the request is issued.
  final int maxWaitTime;

  /// Minimum number of bytes of messages that must be available
  /// to give a response.
  final int minBytes;

  KafkaClient _client;
  KafkaHost _host;

  Map<String, List<_FetchPartitionInfo>> _topics = new Map();

  /// Creates new instance of FetchRequest.
  FetchRequest(
      KafkaClient client, KafkaHost host, this.maxWaitTime, this.minBytes) {
    this._client = client;
    this._host = host;
  }

  /// Adds [topicName] with [paritionId] to this FetchRequest. [fetchOffset]
  /// defines the offset to begin this fetch from.
  void add(String topicName, int partitionId, int fetchOffset,
      [int maxBytes = 65536]) {
    //
    if (!_topics.containsKey(topicName)) {
      _topics[topicName] = new List();
    }
    _topics[topicName]
        .add(new _FetchPartitionInfo(partitionId, fetchOffset, maxBytes));
  }

  Future<FetchResponse> send() async {
    var data = await _client.send(_host, this);
    return new FetchResponse.fromData(data);
  }

  @override
  List<int> toBytes() {
    var builder = new KafkaBytesBuilder();
    _writeHeader(builder, apiKey, apiVersion, 0);
    builder.addInt32(_replicaId);
    builder.addInt32(maxWaitTime);
    builder.addInt32(minBytes);

    builder.addInt32(_topics.length);
    _topics.forEach((topicName, partitions) {
      builder.addString(topicName);
      builder.addInt32(partitions.length);
      partitions.forEach((p) {
        builder.addInt32(p.partitionId);
        builder.addInt64(p.fetchOffset);
        builder.addInt32(p.maxBytes);
      });
    });

    var body = builder.takeBytes();
    builder.addBytes(body);

    return builder.takeBytes();
  }
}

class _FetchPartitionInfo {
  int partitionId;
  int fetchOffset;
  int maxBytes;
  _FetchPartitionInfo(this.partitionId, this.fetchOffset, this.maxBytes);
}

/// Result of [FetchRequest] as defined in Kafka protocol spec.
class FetchResponse {
  Map<String, List<FetchedPartitionData>> topics = new Map();

  FetchResponse.fromData(List<int> data) {
    print(data.length);
    var reader = new KafkaBytesReader.fromBytes(data);
    var size = reader.readInt32();
    assert(size == data.length - 4);

    var correlationId = reader.readInt32(); // TODO verify correlationId

    var count = reader.readInt32();
    while (count > 0) {
      var topicName = reader.readString();
      topics[topicName] = new List();
      var partitionCount = reader.readInt32();
      while (partitionCount > 0) {
        topics[topicName].add(new FetchedPartitionData.readFrom(reader));
        partitionCount--;
      }
      count--;
    }
  }
}

class FetchedPartitionData {
  int partitionId;
  int errorCode;
  int highwaterMarkOffset;
  MessageSet messages;

  FetchedPartitionData.readFrom(KafkaBytesReader reader) {
    partitionId = reader.readInt32();
    errorCode = reader.readInt16();
    highwaterMarkOffset = reader.readInt64();
    var messageSetSize = reader.readInt32();
    var data = reader.readRaw(messageSetSize);
    var messageReader = new KafkaBytesReader.fromBytes(data);
    messages = new MessageSet.readFrom(messageReader);
  }
}
