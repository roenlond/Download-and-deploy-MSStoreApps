# This script is not used in any automation, it's used when developing

# Updates the mold manifest after changing the Deploy-Application template
Update-MoldManifest  .\Templates

# Updates the answer file template (Mold_Answer_File.json)
New-MoldAnswerFile -TemplatePath .\Templates 