### Restoring PostgreSQL Database Locks me Out of the Web GUI ###

#### Symptom ####

When I restore the PostgreSQL database, I can no longer log in to the Web GUI.

#### Root Cause ####

The admin password is stored in Kubernetes as a secret called `DD_ADMIN_PASSWORD`. This secret is re-created (with different values) every time DefectDojo instance is installed/re-installed.

Moreover, this password is written to the PostgreSQL database and reinstated whenever a data restore is triggered.

#### Solution ####

Source the __kubeconfig__ file relative to the target environment and run the following commands:

```
$ kubectl get pods

NAME                                            READY   STATUS      RESTARTS   AGE
defectdojo-celery-beat-6cb4c6897c-5t281         1/1     Running     0          29d
defectdojo-celery-worker-5787df4578-4r5at       1/1     Running     0          29d
defectdojo-django-848c45f9d4-tcx87              2/2     Running     1          37d
defectdojo-initializer-2021-01-27-09-10-rmhld   0/1     Completed   0          44d
defectdojo-postgresql-0                         2/2     Running     0          44d
defectdojo-rabbitmq-0                           1/1     Running     0          30d
hostpathtest-7666c596b7-au7mx                   1/1     Running     0          37d

$ kubectl exec defectdojo-django-${POD_IDENTIFIER} -c uwsgi -- ./manage.py changepassword
```

Change the password and try to log in to the Web GUI again.

Consider creating a separate super user account that remains consistent across database restores.

### Restoring PostgreSQL Database Crashes the Web GUI ###

#### Symptom ####

When I restore the PostgreSQL database, I can log in to DefectDojo, but I'm unable to browse to any section. I get an error message.

#### Root Cause ####

Most likely, you are attempting to restore the PostgreSQL database into a newer version of DefectDojo that requires a database migration.

#### Solution ####

Source the __kubeconfig__ file relative to the target environment and run the following commands:

```
$ kubectl get pods

NAME                                            READY   STATUS      RESTARTS   AGE
defectdojo-celery-beat-6cb4c6897c-5t281         1/1     Running     0          29d
defectdojo-celery-worker-5787df4578-4r5at       1/1     Running     0          29d
defectdojo-django-848c45f9d4-tcx87              2/2     Running     1          37d
defectdojo-initializer-2021-01-27-09-10-rmhld   0/1     Completed   0          44d
defectdojo-postgresql-0                         2/2     Running     0          44d
defectdojo-rabbitmq-0                           1/1     Running     0          30d
hostpathtest-7666c596b7-au7mx                   1/1     Running     0          37d

$ kubectl exec defectdojo-django-${POD_IDENTIFIER} -c uwsgi -- ./manage.py migrate

Operations to perform:
  Apply all migrations: admin, auditlog, auth, authtoken, contenttypes, django_celery_results, dojo, sessions, sites, social_django, tagging, tastypie, watson
Running migrations:
  Applying dojo.0071_product_type_enhancement... OK
  Applying dojo.0072_composite_index... OK
  Applying dojo.0073_sheets_textfields... OK
  Applying dojo.0074_notifications_close_engagement... OK
  Applying dojo.0075_import_history... OK
  Applying dojo.0076_authorization... OK
  Applying dojo.0077_delete_dupulicates... OK
  Applying dojo.0078_cvssv3_rename_verbose_name... OK
```

Log out of the appplication and log back in.

Always check DefectDojo [release notes](https://github.com/DefectDojo/django-DefectDojo/releases/) before restoring the database into a new major release version.
