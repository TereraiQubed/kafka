import 'dart:async';

import 'package:kafka/ng.dart';

Future main() async {
  var session = new Session([new ContactPoint('127.0.0.1:9092')]);
  var producer = new Producer<String, String>(
      new StringSerializer(), new StringSerializer(), session);
  // Loop through a list of partitions.
  for (var p in [0, 1, 2]) {
    var result = await producer
        .send(new ProducerRecord('simple_topic', p, 'key:${p}', 'value:${p}'));
    print(result);
  }
  await session.close(); // Always close session in the end.
}