from dotenv import load_dotenv
import os
import openai

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))
api_key = os.getenv('OPENAI_API_KEY')
if not api_key:
    print('OPENAI_API_KEY not set in .env')
    raise SystemExit(1)

client = openai.OpenAI(api_key=api_key)

print('Listing models (this may include many). Filtering for vision/gpt names...')
try:
    models = client.models.list().data
except Exception as e:
    print('Error listing models:', e)
    raise

vision_candidates = []
for m in models:
    mid = getattr(m, 'id', None) or m.get('id')
    print(mid)
    if 'vision' in mid.lower() or 'gpt-4' in mid.lower() or 'gpt-4o' in mid.lower() or 'gpt-4o-mini' in mid.lower():
        vision_candidates.append(mid)

print('\nFiltered vision/gpt candidates:')
for v in vision_candidates:
    print(' -', v)
