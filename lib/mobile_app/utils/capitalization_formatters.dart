import 'package:flutter/services.dart';

/// Input formatter for proper name fields (Last Name, First Name).
/// - Allows: letters (a–z, A–Z, accented/unicode), spaces, hyphens, apostrophes, dots
/// - Blocks: numbers (0–9), and all other symbols
/// - Auto-capitalizes the first letter of each word
/// Supports real-world names like: De La Cruz, O'Brien, Anne-Marie, Jr., Ñoño
class NameInputFormatter extends TextInputFormatter {
  const NameInputFormatter();

  // Characters allowed in a proper name
  static final _allowed = RegExp(
    r"[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF \-'\.]",
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final raw = newValue.text;
    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < raw.length; i++) {
      final char = raw[i];

      // Block any character not in the allowed set
      if (!_allowed.hasMatch(char)) continue;

      // Prevent leading spaces
      if (char == ' ' && buffer.isEmpty) continue;

      // Prevent double spaces
      if (char == ' ' && buffer.isNotEmpty && buffer.toString().endsWith(' ')) continue;

      // Auto-capitalize first letter of each word
      if (capitalizeNext && RegExp(r'[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]').hasMatch(char)) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
        // Capitalize next word after these delimiters
        if (char == ' ' || char == '-' || char == "'") {
          capitalizeNext = true;
        }
      }
    }

    final result = buffer.toString();

    // Clamp the selection to the new text length
    final selectionOffset = newValue.selection.extentOffset.clamp(0, result.length);
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }
}

/// Formats text in real-time so that each word starts with a capital letter.
/// Works across Web, Desktop, and Mobile (hardware and software keyboards).
class CapitalizeWordsInputFormatter extends TextInputFormatter {
  const CapitalizeWordsInputFormatter();


  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final text = newValue.text;
    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (capitalizeNext && RegExp(r'[a-zA-Z]').hasMatch(char)) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
        if (char == ' ' ||
            char == '\t' ||
            char == '\n' ||
            char == '-' ||
            char == '_' ||
            char == '/' ||
            char == '\\' ||
            char == '(' ||
            char == '[' ||
            char == '{' ||
            char == '"' ||
            char == '\'' ||
            char == ',' ||
            char == '.') {
          capitalizeNext = true;
        }
      }
    }

    return newValue.copyWith(
      text: buffer.toString(),
      selection: newValue.selection,
    );
  }
}

/// Formats text in real-time so that the first letter of each sentence is capitalized.
class CapitalizeSentencesInputFormatter extends TextInputFormatter {
  const CapitalizeSentencesInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final text = newValue.text;
    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (capitalizeNext && RegExp(r'[a-zA-Z]').hasMatch(char)) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
        if (char == '.' || char == '!' || char == '?' || char == '\n' || char == ':') {
          capitalizeNext = true;
        }
      }
    }

    return newValue.copyWith(
      text: buffer.toString(),
      selection: newValue.selection,
    );
  }
}

/// Input formatter for Middle Initial field.
/// - Automatically converts any typed letter to uppercase (e.g. 'i' -> 'I')
/// - Restricts to a single uppercase letter
/// - Blocks numbers, spaces, dots, and symbols
class MiddleInitialInputFormatter extends TextInputFormatter {
  const MiddleInitialInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Filter to allowed letters only (including accents and Ñ)
    final letters = newValue.text.replaceAll(
      RegExp(r"[^a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]"),
      '',
    );

    if (letters.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Take the last typed letter so typing another letter replaces the previous one
    final letter = letters[letters.length - 1].toUpperCase();

    return TextEditingValue(
      text: letter,
      selection: const TextSelection.collapsed(offset: 1),
    );
  }
}
