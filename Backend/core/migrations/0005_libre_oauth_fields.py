from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0004_add_insulin_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='libreconnection',
            name='refresh_token',
            field=models.CharField(max_length=500, null=True, blank=True),
        ),
        migrations.AddField(
            model_name='libreconnection',
            name='token_type',
            field=models.CharField(max_length=50, null=True, blank=True),
        ),
        migrations.AddField(
            model_name='libreconnection',
            name='token_expires_at',
            field=models.DateTimeField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='libreconnection',
            name='scope',
            field=models.CharField(max_length=200, null=True, blank=True),
        ),
        migrations.AddField(
            model_name='libreconnection',
            name='last_synced',
            field=models.DateTimeField(null=True, blank=True),
        ),
    ]
