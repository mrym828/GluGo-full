from rest_framework import serializers
from .models import FoodEntry, GlucoseRecord, NutritionalInfo
from .services.insulin import calculate_insulin

class NutritionalInfoSerializer(serializers.ModelSerializer):
    class Meta:
        model = NutritionalInfo
        fields = '__all__'
    
    def create(self, validated_data):
        return NutritionalInfo.objects.create(**validated_data)


class FoodEntrySerializer(serializers.ModelSerializer):
    nutritional_info = NutritionalInfoSerializer(read_only=True)
    total_carbs_g = serializers.FloatField(write_only = True, required= False)

    class Meta:
        model = FoodEntry
        fields = (
            'id', 'user', 'food_name', 'description', 'timestamp', 'meal_type',
            'image', 'nutritional_info', 'insulin_recommended', 'insulin_rounded'
        )
        read_only_fields = ('insulin_recommended', 'insulin_rounded', 'user')
    
    def create(self, validated_data):
        total_carbs_g = validated_data.pop('total_carbs_g', None)
        validated_data.pop('user', None)

        #build foodentry for user
        user = self.context['request'].user
        instance = FoodEntry.objects.create(user=user, **validated_data)


        ni_payload = self.initial_data.get('nutritional_info')
        if isinstance(ni_payload, dict):
            ni_serializer = NutritionalInfoSerializer(data= ni_payload)
            ni_serializer.is_valid(raise_exception=True)
            ni = ni_serializer.save()
            instance.nutritional_info=ni
            instance.save(update_fields=['nutritional_info'])
            if total_carbs_g is None and ni.carbs is not None:
                total_carbs_g=ni.carbs
        
        if total_carbs_g is not None:
            carb_ratio = getattr(user, 'insulin_to_carb_ratio', 0) or 0
            correction_factor= getattr(user, 'correction_factor', None)
            current_glucose = None
            try:
                latest = user.glucose_records.order_by('-timestamp').first()
                if latest:
                    current_glucose = latest.glucose_level
            except Exception:
                pass
            
            res = calculate_insulin(
                total_carbs_g=float(total_carbs_g),
                carb_ratio=float(carb_ratio),
                current_glucose=current_glucose,
                correction_factor=correction_factor,
            )
            instance.insulin_recommended = res.get('recommended_dose')
            instance.insulin_rounded= res.get('rounded_dose')
            instance.save(update_fields=['insulin_recommended','insulin_rounded'])
        return instance
     


class GlucoseRecordSerializer(serializers.ModelSerializer):
    value = serializers.FloatField(write_only=True)
    meal_timing = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    mood = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    notes = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    
    class Meta:
        model = GlucoseRecord
        fields = [
            'id', 'user', 'timestamp', 'glucose_level', 'trend_arrow', 'source',
            'value', 'meal_timing', 'mood', 'notes'
        ]
        read_only_fields = ['id', 'user']

    def validate_meal_timing(self, value):
        """Convert frontend meal timing values to model choices"""
        if not value:
            return None
            
        meal_timing_mapping = {
            'Before Meal': 'before_meal',
            'After Meal': 'after_meal', 
            'Fasting': 'fasting',
            'Bedtime': 'bedtime',
            'Random': 'random'
        }
        
        if value in meal_timing_mapping:
            return meal_timing_mapping[value]
        
        # If value is already in correct format, return as is
        if value in dict(GlucoseRecord.MEAL_TIMING_CHOICES):
            return value
            
        raise serializers.ValidationError(f"Invalid meal timing: {value}")

    def validate_mood(self, value):
        """Convert frontend mood values to model choices"""
        if not value:
            return None
            
        # Mapping from frontend values to model choices
        mood_mapping = {
            'Excellent': 'excellent',
            'Good': 'good',
            'Fair': 'fair', 
            'Poor': 'poor'
        }
        
        if value in mood_mapping:
            return mood_mapping[value]
        
        # If value is already in correct format, return as is
        if value in dict(GlucoseRecord.MOOD_CHOICES):
            return value
            
        raise serializers.ValidationError(f"Invalid mood: {value}")

    def create(self, validated_data):
        # Map 'value' to 'glucose_level'
        if 'value' in validated_data:
            validated_data['glucose_level'] = validated_data.pop('value')
        
        # Handle meal_timing and mood conversion
        meal_timing = validated_data.get('meal_timing')
        if meal_timing:
            validated_data['meal_timing'] = self.validate_meal_timing(meal_timing)
            
        mood = validated_data.get('mood')
        if mood:
            validated_data['mood'] = self.validate_mood(mood)
        
        return super().create(validated_data)

    def update(self, instance, validated_data):
        # Handle value mapping for updates too
        if 'value' in validated_data:
            validated_data['glucose_level'] = validated_data.pop('value')
            
        # Handle meal_timing and mood conversion for updates
        if 'meal_timing' in validated_data:
            meal_timing = validated_data['meal_timing']
            if meal_timing:
                validated_data['meal_timing'] = self.validate_meal_timing(meal_timing)
                
        if 'mood' in validated_data:
            mood = validated_data['mood']
            if mood:
                validated_data['mood'] = self.validate_mood(mood)
        
        return super().update(instance, validated_data)