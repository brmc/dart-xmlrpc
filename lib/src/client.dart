// Copyright (c) 2015, Alexandre Ardhuin. All rights reserved. Use of this
// source code is governed by a BSD-style license that can be found in the
// LICENSE file.

library xml_rpc.src.client;

import 'dart:async';
import 'dart:convert' show Encoding;

import 'package:http/http.dart' as http show post, Client;
import 'package:xml/xml.dart';

import 'common.dart';
import 'converter.dart';

export 'common.dart';

/// Make a xmlrpc call to the given [url], which can be a [Uri] or a [String].
///
/// [encoding] defaults to [UTF8].
Future call(
  url,
  String methodName,
  List params, {
  Map<String, String> headers,
  Encoding encoding,
  http.Client client,
}) async {
  final xml = convertMethodCall(methodName, params).toXmlString();

  final _headers = <String, String>{'Content-Type': 'text/xml'};
  if (headers != null) _headers.addAll(headers);

  final post = client != null ? client.post : http.post;
  final response =
      await post(url, headers: _headers, body: xml, encoding: encoding);
  if (response.statusCode != 200) return new Future.error(response);
  final body = response.body;
  final value = decodeResponse(parse(body));
  if (value is Fault)
    return new Future.error(value);
  else
    return new Future.value(value);
}

XmlDocument convertMethodCall(String methodName, List params) {
  final methodCallChildren = [
    new XmlElement(new XmlName('methodName'), [], [new XmlText(methodName)])
  ];
  if (params != null && params.isNotEmpty) {
    methodCallChildren.add(new XmlElement(
        new XmlName('params'),
        [],
        params.map((p) => new XmlElement(new XmlName('param'), [], [
              new XmlElement(new XmlName('value'), [], [encode(p)])
            ]))));
  }
  return new XmlDocument([
    new XmlProcessing('xml', 'version="1.0"'),
    new XmlElement(new XmlName('methodCall'), [], methodCallChildren)
  ]);
}

decodeResponse(XmlDocument document) {
  final responseElt = document.findElements('methodResponse').first;
  final paramsElts = responseElt.findElements('params');
  if (paramsElts.isNotEmpty) {
    final paramElt = paramsElts.first.findElements('param').first;
    final valueElt = paramElt.findElements('value').first;
    final elt = getValueContent(valueElt);
    return decode(elt);
  } else {
    int faultCode;
    String faultString;
    responseElt
        .findElements('fault')
        .first
        .findElements('value')
        .first
        .findElements('struct')
        .first
        .findElements('member')
        .forEach((memberElt) {
      final name = memberElt.findElements('name').first.text;
      final valueElt = memberElt.findElements('value').first;
      final elt = getValueContent(valueElt);
      final value = decode(elt);
      if (name == 'faultCode')
        faultCode = value;
      else if (name == 'faultString')
        faultString = value;
      else
        throw new FormatException();
    });
    return new Fault(faultCode, faultString);
  }
}
