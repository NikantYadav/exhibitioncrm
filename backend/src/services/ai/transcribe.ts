import { AIService } from '../../config/ai';

export async function transcribeAudio(audioData: string) {
  try {
    const text = await AIService.transcribeAudio(audioData);

    return {
      success: true,
      data: { text }
    };
  } catch (error) {
    console.error('Transcription error:', error);
    throw error;
  }
}
