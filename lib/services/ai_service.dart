import '../models/ai_place.dart';
import '../models/ai_recommendation.dart';
class AiService {
  Future<AiRecommendation> ask({
    required String message,
    required List<AiPlace> places,
  }) async {
    /*
      Your friend will implement the LLM here.

      The LLM receives:
        - message
        - available places

      and returns a response.
    */

    return AiRecommendation(
      placeId: 1,
      message: 'I recommend this place.',
    );
  }
}