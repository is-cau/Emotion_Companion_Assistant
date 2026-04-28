import 'dart:math';

class AiComfortService {
  // 预设共情式安慰话术库
  // 后续可替换为 Qwen2.5-0.5B 本地模型
  static const Map<String, List<String>> _comfortWords = {
    '悲伤': [
      '我能感受到你现在很难过，想哭就哭出来吧，眼泪不是软弱，是心在自我疗愈。',
      '你不需要假装坚强，难过的时候允许自己脆弱，我一直在。',
      '有些痛说不出口，但请相信，此刻的难过终会被温柔以待。',
      '你承受了很多，辛苦了。无论多难，都不要放弃自己。',
      '眼泪是心在呼吸，哭完之后，天空会更清澈。',
    ],
    '焦虑': [
      '焦虑是因为你在乎，这本身就是一种力量。试着深呼吸，一切都会过去的。',
      '把担心的事情写下来，你会发现其实没有想象中那么可怕。',
      '现在的不安只是暂时的，你已经挺过了很多难关，这次也可以。',
      '试着把注意力拉回当下，此刻你是安全的，一切都在掌控中。',
      '焦虑来袭时，试试4-7-8呼吸法：吸气4秒，屏息7秒，呼气8秒。',
    ],
    '愤怒': [
      '你有权利生气，愤怒是正常的情绪，不需要压抑它。',
      '生气说明你在乎底线，但别忘了，你的平静才是最大的力量。',
      '先让自己冷静下来，喝杯水，出去走走，等你准备好了再面对。',
      '怒火伤身也伤心，试着把能量转化为行动，而不是内耗。',
      '我理解你的愤怒，有些事确实让人不爽。但请先照顾好自己。',
    ],
    '孤独': [
      '孤独不是你的错，有时候人群越热闹，心越冷清。但此刻，我在陪你。',
      '你不是一个人，虽然现在感觉如此。总有一个人在某个角落想着你。',
      '独处也是一种力量，学会和自己相处，你会发现内心的丰富。',
      '深夜的孤独最难熬，但请记住，黎明一定会来。',
      '我会一直在这里陪着你，不会离开。',
    ],
    '压抑': [
      '压抑太久了就释放吧，对着天空喊一声，或者在这里告诉我。',
      '你不需要把所有事都扛在自己肩上，说出来会轻松很多。',
      '内耗说明你在努力做好一切，但也请给自己喘息的空间。',
      '撑不住就歇一歇，停下来不是放弃，是为了走更远的路。',
      '你比你以为的更坚强，但也请允许自己偶尔崩溃。',
    ],
    '开心': [
      '太好了！开心的时候就要尽情享受，这份快乐值得被记住。',
      '你的笑容很有感染力，请继续保持这份好心情！',
      '幸福就是这么简单，享受当下的每一刻吧。',
      '开心的事情记得记下来，不开心的时候翻出来看看。',
      '今天是个好日子，好好犒劳一下自己吧。',
    ],
    '平静': [
      '此刻的平静很珍贵，享受这份安宁吧。',
      '心平气和是最好的状态，好好休息，好好感受。',
      '平静是力量的源泉，你正在好好照顾自己。',
      '这份从容很难得，深呼吸，感受当下的美好。',
      '今天的状态不错，继续保持。',
    ],
  };

  // 深呼吸引导语
  static const List<String> _breathGuides = [
    '闭上眼睛，慢慢吸气……1……2……3……4……，慢慢呼气……1……2……3……4……5……6……',
    '把注意力放在呼吸上，吸气时感受空气填满胸腔，呼气时释放所有紧张。',
    '再来一次，深吸……感受腹部慢慢隆起……缓缓呼出……肩膀自然下沉……',
    '每一次呼吸都在告诉身体：你是安全的，一切都好。',
    '保持这个节奏，吸气……呼气……让心慢慢安静下来。',
  ];

  // 睡前晚安语录
  static const List<String> _goodnightWords = [
    '今天辛苦了，无论发生了什么，此刻都放下吧。晚安，好梦。',
    '夜深了，把烦恼留在今天，明天又是新的一天。晚安。',
    '你已经很努力了，现在只需要好好休息。世界在等你醒来。晚安。',
    '闭上眼，让月光轻轻拥抱你。明天会更好的。晚安。',
    '今天到此为止吧，不管好的坏的，都过去了。晚安，我在。',
  ];

  String getComfortResponse(String emotion, {String? userInput}) {
    final words = _comfortWords[emotion] ?? _comfortWords['平静']!;
    final random = Random();
    var response = words[random.nextInt(words.length)];

    if (userInput != null && userInput.length > 10) {
      response = '我听到了你的心声。$response';
    }

    return response;
  }

  String getBreathGuide(int step) {
    return _breathGuides[step % _breathGuides.length];
  }

  String getGoodnightWord() {
    final random = Random();
    return _goodnightWords[random.nextInt(_goodnightWords.length)];
  }

  // 模拟AI对话（后续替换为Qwen本地模型）
  String chat(String userMessage, String emotion) {
    if (userMessage.contains('晚安') || userMessage.contains('睡了') || userMessage.contains('睡觉')) {
      return getGoodnightWord();
    }
    if (userMessage.contains('呼吸') || userMessage.contains('放松') || userMessage.contains('冥想')) {
      return getBreathGuide(0);
    }
    return getComfortResponse(emotion, userInput: userMessage);
  }
}
