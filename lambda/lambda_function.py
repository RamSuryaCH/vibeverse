import json
import boto3
import base64
import os

bedrock = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
polly   = boto3.client('polly',           region_name=os.environ.get('AWS_REGION', 'us-east-1'))

SYSTEM_PROMPT = """You are VibeVerse, a creative mood-to-story generator.
Given a mood, feeling, or life moment, respond with ONLY valid JSON (no markdown, no explanation):
{
  "story_paragraphs": [
    "First paragraph of the creative story or poem capturing the mood. Make it vivid, emotional, and personal.",
    "Second paragraph of the creative story or poem.",
    "Third paragraph of the creative story or poem."
  ],
  "playlist_title": "A creative, evocative playlist name for this exact mood (e.g. 'Midnight Fog & Coffee Spills')",
  "tracks": [
    "Track theme 1 — short evocative description",
    "Track theme 2 — short evocative description",
    "Track theme 3 — short evocative description",
    "Track theme 4 — short evocative description",
    "Track theme 5 — short evocative description"
  ],
  "color_palette": ["#hexcode1", "#hexcode2", "#hexcode3", "#hexcode4"],
  "palette_description": "One sentence poetic description of the color palette and what feeling it evokes",
  "vibe_tag": "A single word or short phrase that is the essence of this vibe (e.g. 'Bittersweet Nostalgia')"
}"""


def handler(event, context):
    cors_headers = {
        'Access-Control-Allow-Origin':  '*',
        'Access-Control-Allow-Methods': 'POST,OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Content-Type': 'application/json',
    }

    method = (event.get('requestContext') or {}).get('http', {}).get('method', 'POST')
    if method == 'OPTIONS':
        return {'statusCode': 200, 'headers': cors_headers, 'body': ''}

    try:
        body = json.loads(event.get('body') or '{}')
        mood = (body.get('mood') or '').strip()
        if not mood:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'mood is required'}),
            }

        bedrock_payload = {
            "messages": [
                {"role": "user", "content": [{"text": f"My mood / life moment: {mood}"}]}
            ],
            "system": [{"text": SYSTEM_PROMPT}],
            "inferenceConfig": {
                "maxTokens": 1000,
                "temperature": 0.92,
                "topP": 0.95,
            },
        }
        br_response = bedrock.invoke_model(
            modelId='amazon.nova-lite-v1:0',
            body=json.dumps(bedrock_payload),
            contentType='application/json',
            accept='application/json',
        )
        br_body   = json.loads(br_response['body'].read())
        raw_text  = br_body['output']['message']['content'][0]['text']

        raw_text = raw_text.strip()
        if raw_text.startswith('```'):
            raw_text = raw_text.split('```')[1]
            if raw_text.startswith('json'):
                raw_text = raw_text[4:]
        vibe_data = json.loads(raw_text.strip())

        # Join paragraphs and set 'story' key
        paragraphs = vibe_data.get('story_paragraphs', [])
        if not paragraphs and 'story' in vibe_data:
            story_text = vibe_data['story']
        else:
            story_text = "\n\n".join(paragraphs)
            vibe_data['story'] = story_text

        polly_resp = polly.synthesize_speech(
            Text=story_text[:2999],
            OutputFormat='mp3',
            VoiceId='Joanna',
            Engine='neural',
        )
        audio_bytes = polly_resp['AudioStream'].read()
        vibe_data['audio_base64'] = base64.b64encode(audio_bytes).decode('utf-8')
        vibe_data['mood_input']   = mood

        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(vibe_data),
        }

    except json.JSONDecodeError as e:
        return {
            'statusCode': 502,
            'headers': cors_headers,
            'body': json.dumps({'error': f'Model returned invalid JSON: {str(e)}'}),
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)}),
        }
