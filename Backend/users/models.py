from django.contrib.auth.models import AbstractUser
from django.db import models


class DiabetesType(models.TextChoices):
    TYPE1 = "T1", "Type 1"
    TYPE2 = "T2", "Type 2"


class User(AbstractUser):
    # Existing diabetic-specific fields
    diabetes_type = models.CharField(
        max_length=10,
        choices=DiabetesType.choices,
        blank=True,
        null=True,
    )
    insulin_to_carb_ratio = models.FloatField(blank=True, null=True)
    correction_factor = models.FloatField(blank=True, null=True)

    # Contact and identity
    phone_number = models.CharField(max_length=30, blank=True, null=True)
    full_name = models.CharField(max_length=200, blank=True, null=True)

    # Clinical / demographics
    diagnoses_year = models.IntegerField(blank=True, null=True)
    age = models.IntegerField(blank=True, null=True)

    class Gender(models.TextChoices):
        MALE = "M", "Male"
        FEMALE = "F", "Female"

    gender = models.CharField(
        max_length=2, 
        choices=Gender.choices, 
        blank=True,  
        null=True,   
        default='F'  
    )

    weight_kg = models.FloatField(blank=True, null=True)
    height_cm = models.FloatField(blank=True, null=True)

    # Medication and targets
    preferred_med = models.CharField(max_length=200, blank=True, null=True)
    target_glucose_min = models.IntegerField(blank=True, null=True)
    target_glucose_max = models.IntegerField(blank=True, null=True)
    preferred_carb_ratio = models.FloatField(blank=True, null=True)

    # Freestyle Libre integration credentials 
    libre_registered = models.BooleanField(default=False)  
    libre_username = models.CharField(max_length=200, blank=True, null=True)
    libre_password = models.CharField(max_length=200, blank=True, null=True)

    def __str__(self):
        return self.username