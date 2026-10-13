# Known false positive in Gettext's generated backend module. It appears when a
# plural message (ngettext) is present: Dialyzer reports `call_without_opaque`
# on `Expo.PluralForms`, which is an opaque type from the Gettext dependency.
# Only this file and this warning type are ignored, so other warnings still fail CI.
[
  {"lib/freguesia_web/gettext.ex", :call_without_opaque}
]
