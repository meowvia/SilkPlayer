//
//  SilkLanguageHelper.swift
//  SilkPlayer
//
//  Created for SilkPlayer - Native Media Language Helper.
//

import Foundation

public enum SilkLanguageHelper {
    public static func localizedLanguageName(for code: String) -> String {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty && clean != "und" else { return "" }
        let map: [String: String] = [
            "chi": "中文", "zho": "中文", "zh": "中文",
            "chs": "简体中文", "cht": "繁体中文",
            "eng": "English", "en": "English",
            "jpn": "日本語", "ja": "日本語",
            "kor": "한국어", "ko": "한국어",
            "fre": "Français", "fra": "Français", "fr": "Français",
            "ger": "Deutsch", "deu": "Deutsch", "de": "Deutsch",
            "spa": "Español", "es": "Español",
            "rus": "Русский", "ru": "Русский",
            "ita": "Italiano", "it": "Italiano",
            "por": "Português", "pt": "Português",
            "ara": "العربية", "ar": "العربية",
            "dan": "Dansk", "da": "Dansk",
            "dut": "Nederlands", "nld": "Nederlands", "nl": "Nederlands",
            "fin": "Suomi", "fi": "Suomi",
            "gre": "Ελληνικά", "ell": "Ελληνικά", "el": "Ελληνικά",
            "heb": "עברית", "he": "עברית",
            "hun": "Magyar", "hu": "Magyar",
            "ind": "Bahasa Indonesia", "id": "Bahasa Indonesia",
            "nor": "Norsk", "no": "Norsk",
            "pol": "Polski", "pl": "Polski",
            "swe": "Svenska", "sv": "Svenska",
            "tha": "ไทย", "th": "ไทย",
            "tur": "Türkçe", "tr": "Türkçe",
            "ukr": "Українська", "uk": "Українська",
            "vie": "Tiếng Việt", "vi": "Tiếng Việt",
            "cze": "Čeština", "ces": "Čeština", "cs": "Čeština",
            "rum": "Română", "ron": "Română", "ro": "Română",
            "bul": "Български", "bg": "Български",
            "hrv": "Hrvatski", "hr": "Hrvatski",
            "est": "Eesti", "et": "Eesti",
            "ice": "Íslenska", "isl": "Íslenska", "is": "Íslenska",
            "lav": "Latviešu", "lv": "Latviešu",
            "lit": "Lietuvių", "lt": "Lietuvių",
            "slv": "Slovenščina", "sl": "Slovenščina",
            "srp": "Srpski", "sr": "Srpski"
        ]
        return map[clean] ?? Locale.current.localizedString(forLanguageCode: clean) ?? clean.uppercased()
    }
}
