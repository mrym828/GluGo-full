# Generated migration to add insulin recommendation fields to FoodEntry
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0003_libreconnection_password_encrypted'),
    ]

    operations = [
        migrations.AddField(
            model_name='foodentry',
            name='insulin_recommended',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='foodentry',
            name='insulin_rounded',
            field=models.FloatField(blank=True, null=True),
        ),
    ]
