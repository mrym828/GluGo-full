
from dotenv import load_dotenv
import os
import openai
import base64
import json

ROOT = os.path.abspath(os.getcwd())
ENV_PATH = os.path.join(ROOT, '.env')
load_dotenv(ENV_PATH)
API_KEY = os.getenv('OPENAI_API_KEY')
if not API_KEY:
    print('OPENAI_API_KEY not set in .env; aborting.')
    raise SystemExit(1)

# Candidate models in preferred order
CANDIDATES = [
    'gpt-image-1',
    'gpt-4-1106-preview',
    'gpt-4-0613',
    'gpt-4-turbo',
    'gpt-4'
]

IMAGE_PATH = os.path.abspath(os.path.join(ROOT, '..', 'burger.jpg'))
if not os.path.exists(IMAGE_PATH):
    print('Could not find burger.jpg at', IMAGE_PATH)
    raise SystemExit(1)

with open(IMAGE_PATH, 'rb') as f:
    b = f.read()
    b64 = base64.b64encode(b).decode('utf-8')
    data_uri = f"data:image/jpeg;base64,{b64}"

client = openai.OpenAI(api_key=API_KEY)

system_instruction = (
    "You are a helpful assistant. Look at the image and in one short sentence say what the main object/food is. "
    "Keep the response concise."
)

for model in CANDIDATES:
    print('\n--- Trying model:', model)
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system_instruction},
                {"role": "user", "content": [
                    {"type": "text", "text": "Identify the main food or object in the image in one short sentence."},
                    {"type": "image_url", "image_url": {"url": data_uri}}
                ]}
            ],
            max_tokens=60,
            temperature=0
        )
        # Try to extract text
        try:
            text = resp.choices[0].message.content
        except Exception:
            text = resp['choices'][0]['message']['content']
        print('SUCCESS:', text)
        # Update .env to this model
        # Read .env
        with open(ENV_PATH, 'r', encoding='utf-8') as fh:
            env_text = fh.read()
        if 'OPENAI_VISION_MODEL=' in env_text:
            # replace line
            new_env_text = ''
            for line in env_text.splitlines():
                if line.startswith('OPENAI_VISION_MODEL='):
                    new_env_text += f'OPENAI_VISION_MODEL={model}\n'
                else:
                    new_env_text += line + '\n'
        else:
            new_env_text = env_text + f'\nOPENAI_VISION_MODEL={model}\n'
        with open(ENV_PATH, 'w', encoding='utf-8') as fh:
            fh.write(new_env_text)
        print('Updated', ENV_PATH, 'with OPENAI_VISION_MODEL=', model)
        break
    except Exception as e:
        # Print a compact error
        try:
            err_str = str(e)
        except Exception:
            err_str = repr(e)
        print('ERROR for model', model, ':', err_str)
else:
    print('\nNo candidate model succeeded. Check API key, account permissions, or try other model names.')

