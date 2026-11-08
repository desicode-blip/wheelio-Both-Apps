import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget demoEvidence({required bool capture}) => SizedBox(
  key: ValueKey(capture),
  height: capture ? 360 : 260,
  child: HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      frame.src = '/evidence.html?capture=$capture';
      frame.title = capture ? 'Record video evidence' : 'View video evidence';
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
      frame.allow = 'camera; microphone';
    },
  ),
);
