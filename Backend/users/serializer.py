from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()

class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'password_confirm', 'full_name', 'gender')

    def validate(self, data):
        if data['password'] != data['password_confirm']:
            raise serializers.ValidationError("Passwords don't match")
        return data

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
            full_name=validated_data.get('full_name', ''),
            gender=validated_data.get('gender', 'M'),
        )
        return user


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            'id', 'username', 'email', 'full_name', 'phone_number',
            'diabetes_type', 'diagnoses_year', 'age', 'gender',
            'weight_kg', 'height_cm', 'insulin_to_carb_ratio',
            'correction_factor', 'target_glucose_min', 'target_glucose_max'
        )
        read_only_fields = ('id', 'username')


class UserUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            'full_name', 'email', 'phone_number', 'diabetes_type',
            'diagnoses_year', 'age', 'gender', 'weight_kg', 'height_cm',
            'insulin_to_carb_ratio', 'correction_factor',
            'target_glucose_min', 'target_glucose_max'
        )