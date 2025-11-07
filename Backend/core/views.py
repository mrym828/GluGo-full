from django.shortcuts import render
from django.http import HttpResponse, JsonResponse
from django.db.models.functions import Lower
from requests import Response
from rest_framework.views import APIView
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from core.serializers import GlucoseRecordSerializer  
from core.models import GlucoseRecord, Images
import base64
import openai
from django.conf import settings
import json
import re


def aiopen(request):
    result_text = None

    if request.method == "POST":
        if not request.FILES.get("meal_image"):
            result_text = "No image uploaded. Please choose an image and submit the form."
            return render(request, "core/openai.html", {"result": result_text})

        image_file = request.FILES["meal_image"]
        print("Uploaded image:", image_file)

        # Convert image to base64
        image_bytes = image_file.read()
        base64_image = base64.b64encode(image_bytes).decode("utf-8")

        # Use OpenAI client
        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)

      
    
        system_instruction = (
            "You are a food nutrition assistant.\n"
            "Given an image, identify the main dish and the individual components/ingredients that make up the meal. For each component, estimate the amount of carbohydrates (in grams) that component contributes.\n"
            "Return a single valid JSON object ONLY (no surrounding text) with the following schema:\n"
            "{\n"
            "  \"name\": string,\n"
            "  \"components\": [ { \"name\": string, \"carbs_g\": number } ],\n"
            "  \"total_carbs_g\": number,\n"
            "  \"confidence\": number,\n"
            "  \"calories_estimate\": number (optional)\n"
            "}\n"
            "Make numeric values plain numbers (not strings), round to one decimal place if needed, and use grams for carbs."
        )

      
        user_message = [
            {"type": "text", "text": "Identify the meal and list components with estimated carbs in grams, then compute total_carbs_g as the sum."},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}}
        ]

        response = client.chat.completions.create(
            model=settings.OPENAI_VISION_MODEL,
            messages=[
                {"role": "system", "content": system_instruction},
                {"role": "user", "content": user_message}
            ],
            max_tokens=500,
            temperature=0
        )

        try:
            raw_text = response.choices[0].message.content
        except Exception:
            raw_text = response['choices'][0]['message']['content']
        print("Raw model output:", raw_text)

       
        parsed = None
        try:
            start = raw_text.find('{')
            end = raw_text.rfind('}')
            if start != -1 and end != -1 and end > start:
                json_text = raw_text[start:end+1]
                parsed = json.loads(json_text)
            else:
                parsed = json.loads(raw_text)

            
            if isinstance(parsed, dict):
                comps = parsed.get('components') or parsed.get('ingredients')
                normalized = []
                if comps and isinstance(comps, list):
                    for c in comps:
                        if isinstance(c, dict):
                            name = c.get('name')
                            carbs = c.get('carbs_g') if 'carbs_g' in c else c.get('carbs')
                        else:
                            name = str(c)
                            carbs = None
                        try:
                            if carbs is not None:
                                carbs = round(float(carbs), 1)
                        except Exception:
                            pass
                        normalized.append({'name': name, 'carbs_g': carbs})
                parsed['components'] = normalized

                # Compute total if missing and components contain numeric carbs
                if 'total_carbs_g' not in parsed and parsed.get('components'):
                    s = 0.0
                    have_number = False
                    for c in parsed['components']:
                        try:
                            val = float(c.get('carbs_g'))
                            s += val
                            have_number = True
                        except Exception:
                            pass
                    if have_number:
                        parsed['total_carbs_g'] = round(s, 1)

        except Exception as e:
            print("JSON parse error:", e)
            parsed = None
        result_text = parsed if parsed is not None else raw_text
        return render(request, "core/openai.html", {"result": result_text})

    # For GET (or other methods) render the form with no result
    return render(request, "core/openai.html", {"result": result_text})


def sample_ai_view(request):
    """Simple API endpoint that calls a text model and returns a
    one-line reply as JSON. Useful to verify the text-model config and API
    key without uploading an image.
    """
    try:
        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        resp = client.chat.completions.create(
            model=settings.OPENAI_TEXT_MODEL,
            messages=[{"role": "user", "content": "Say hello in one short sentence"}],
            max_tokens=16,
            temperature=0
        )
        try:
            reply = resp.choices[0].message.content
        except Exception:
            reply = resp['choices'][0]['message']['content']
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

    return JsonResponse({'reply': reply})


class GlucoseRecordListCreateView(generics.ListCreateAPIView):
    serializer_class = GlucoseRecordSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return GlucoseRecord.objects.filter(user=self.request.user)
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
    
    def get_serializer_context(self):
        # Pass request context to serializer
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    

