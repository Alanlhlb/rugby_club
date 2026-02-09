/// Pre-defined venue data with precise coordinates from official LCSD data.
class Venue {
  final String nameCn;
  final String nameEn;
  final String? addressCn;
  final String? addressEn;
  final double latitude;
  final double longitude;

  const Venue({
    required this.nameCn,
    required this.nameEn,
    this.addressCn,
    this.addressEn,
    required this.latitude,
    required this.longitude,
  });

  /// Display label: "中文名 (English Name)"
  String get displayName => '$nameCn ($nameEn)';

  /// Searchable text combining all name/address fields (lowercased).
  String get searchText =>
      '$nameCn $nameEn ${addressCn ?? ''} ${addressEn ?? ''}'.toLowerCase();
}

/// All known venues (Sports Grounds + Rugby Pitches).
const List<Venue> kVenues = [
  // ── Sports Grounds (運動場) ──
  Venue(
    nameCn: '九龍仔運動場',
    nameEn: 'Kowloon Tsai Sports Ground',
    addressCn: '九龍城延文禮士道13號',
    addressEn: '13 Inverness Road, Kowloon City',
    latitude: 22.330556,
    longitude: 114.184167,
  ),
  Venue(
    nameCn: '巴富街運動場',
    nameEn: 'Perth Street Sports Ground',
    latitude: 22.320556,
    longitude: 114.181111,
  ),
  Venue(
    nameCn: '大埔運動場',
    nameEn: 'Tai Po Sports Ground',
    latitude: 22.455278,
    longitude: 114.162500,
  ),
  Venue(
    nameCn: '天水圍運動場',
    nameEn: 'Tin Shui Wai Sports Ground',
    latitude: 22.454722,
    longitude: 114.005000,
  ),
  Venue(
    nameCn: '元朗大球場',
    nameEn: 'Yuen Long Stadium',
    latitude: 22.442500,
    longitude: 114.021389,
  ),
  Venue(
    nameCn: '兆麟運動場',
    nameEn: 'Siu Lun Sports Ground',
    latitude: 22.385000,
    longitude: 113.978056,
  ),
  Venue(
    nameCn: '屯門鄧肇堅運動場',
    nameEn: 'Tuen Mun Tang Shiu Kin Sports Ground',
    latitude: 22.403889,
    longitude: 113.974167,
  ),
  Venue(
    nameCn: '粉嶺遊樂場',
    nameEn: 'Fanling Recreation Ground',
    latitude: 22.493611,
    longitude: 114.137778,
  ),
  Venue(
    nameCn: '北區運動場',
    nameEn: 'North District Sports Ground',
    latitude: 22.506111,
    longitude: 114.130556,
  ),
  Venue(
    nameCn: '西貢鄧肇堅運動場',
    nameEn: 'Sai Kung Tang Shiu Kin Sports Ground',
    latitude: 22.383611,
    longitude: 114.273333,
  ),
  Venue(
    nameCn: '馬鞍山運動場',
    nameEn: 'Ma On Shan Sports Ground',
    latitude: 22.420833,
    longitude: 114.228333,
  ),
  Venue(
    nameCn: '沙田運動場',
    nameEn: 'Sha Tin Sports Ground',
    latitude: 22.387500,
    longitude: 114.197222,
  ),
  Venue(
    nameCn: '小西灣運動場',
    nameEn: 'Siu Sai Wan Sports Ground',
    latitude: 22.267500,
    longitude: 114.248889,
  ),
  Venue(
    nameCn: '香港仔運動場',
    nameEn: 'Aberdeen Sports Ground',
    latitude: 22.249444,
    longitude: 114.171944,
  ),
  Venue(
    nameCn: '城門谷運動場',
    nameEn: 'Shing Mun Valley Sports Ground',
    latitude: 22.376667,
    longitude: 114.128056,
  ),
  Venue(
    nameCn: '深水埗運動場',
    nameEn: 'Sham Shui Po Sports Ground',
    latitude: 22.336944,
    longitude: 114.152500,
  ),
  Venue(
    nameCn: '斧山道運動場',
    nameEn: 'Hammer Hill Road Sports Ground',
    latitude: 22.338333,
    longitude: 114.207500,
  ),
  Venue(
    nameCn: '葵涌運動場',
    nameEn: 'Kwai Chung Sports Ground',
    latitude: 22.358333,
    longitude: 114.125278,
  ),
  Venue(
    nameCn: '青衣運動場',
    nameEn: 'Tsing Yi Sports Ground',
    latitude: 22.356111,
    longitude: 114.108056,
  ),
  Venue(
    nameCn: '和宜合道運動場',
    nameEn: 'Wo Yi Hop Road Sports Ground',
    latitude: 22.374167,
    longitude: 114.136944,
  ),
  Venue(
    nameCn: '長洲運動場',
    nameEn: 'Cheung Chau Sports Ground',
    latitude: 22.206667,
    longitude: 114.033056,
  ),
  Venue(
    nameCn: '銅鑼灣運動場',
    nameEn: 'Causeway Bay Sports Ground',
    latitude: 22.280556,
    longitude: 114.190556,
  ),
  Venue(
    nameCn: '灣仔運動場',
    nameEn: 'Wan Chai Sports Ground',
    latitude: 22.281389,
    longitude: 114.177778,
  ),
  Venue(
    nameCn: '九龍灣運動場',
    nameEn: 'Kowloon Bay Sports Ground',
    latitude: 22.326944,
    longitude: 114.209722,
  ),
  Venue(
    nameCn: '將軍澳運動場',
    nameEn: 'Tseung Kwan O Sports Ground',
    latitude: 22.312222,
    longitude: 114.263611,
  ),

  // ── Rugby Pitches / Recreation Grounds (欖球場) ──
  Venue(
    nameCn: '大坑東遊樂場',
    nameEn: 'Tai Hang Tung Recreation Ground',
    addressCn: '九龍深水埗界限街63號',
    addressEn: '63 Boundary Street, Sham Shui Po, Kowloon',
    latitude: 22.328056,
    longitude: 114.171389,
  ),

  // ── Other Common Rugby Venues (其他常用場地) ──
  Venue(
    nameCn: '京士柏運動場',
    nameEn: "King's Park Sports Ground",
    addressCn: '尖沙咀京士柏道23號',
    addressEn: '23 King\'s Park Rise, Tsim Sha Tsui',
    latitude: 22.307500,
    longitude: 114.174722,
  ),
  Venue(
    nameCn: '香港足球會',
    nameEn: 'Hong Kong Football Club (HKFC)',
    addressCn: '跑馬地體育路3號',
    addressEn: '3 Sports Road, Happy Valley',
    latitude: 22.271944,
    longitude: 114.183889,
  ),
  Venue(
    nameCn: '掃桿埔運動場',
    nameEn: 'So Kon Po Recreation Ground',
    latitude: 22.275833,
    longitude: 114.188333,
  ),
  Venue(
    nameCn: '跑馬地運動場',
    nameEn: 'Happy Valley Recreation Ground',
    latitude: 22.270833,
    longitude: 114.182500,
  ),
  Venue(
    nameCn: '旺角大球場',
    nameEn: 'Mong Kok Stadium',
    addressCn: '旺角花墟道37號',
    addressEn: '37 Flower Market Road, Mong Kok',
    latitude: 22.321667,
    longitude: 114.170833,
  ),
  Venue(
    nameCn: '九龍仔公園',
    nameEn: 'Kowloon Tsai Park',
    latitude: 22.332778,
    longitude: 114.181944,
  ),
];
