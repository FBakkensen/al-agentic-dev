namespace AgenticDevTools.ALBuild.CodeCoverage;

using System.Tooling;

xmlport 74075 "ALBT Raw Code Coverage"
{
    Caption = 'AL Build Raw Code Coverage';
    Direction = Export;
    Encoding = UTF16;
    Format = Xml;

    schema
    {
        textelement(CodeCoverage)
        {
            textattribute(SchemaVersion)
            {
            }
            tableelement(CoverageLine; "Code Coverage")
            {
                textelement(ObjectTypeCode)
                {
                }
                textelement(ObjectTypeName)
                {
                }
                fieldelement(ObjectId; CoverageLine."Object ID")
                {
                }
                fieldelement(LineNumber; CoverageLine."Line No.")
                {
                }
                textelement(LineTypeCode)
                {
                }
                textelement(LineTypeName)
                {
                }
                textelement(CoverageStatusCode)
                {
                }
                textelement(CoverageStatusName)
                {
                }
                fieldelement(HitCount; CoverageLine."No. of Hits")
                {
                }
                fieldelement(SourceLine; CoverageLine.Line)
                {
                }

                trigger OnPreXmlItem()
                begin
                    CoverageLine.Reset();
                end;

                trigger OnAfterGetRecord()
                var
                    ObjectTypeOrdinal: Integer;
                    LineTypeOrdinal: Integer;
                    CoverageStatusOrdinal: Integer;
                begin
                    ObjectTypeOrdinal := CoverageLine."Object Type";
                    ObjectTypeCode := Format(ObjectTypeOrdinal, 0, 9);
                    ObjectTypeName := Format(CoverageLine."Object Type");
                    LineTypeOrdinal := CoverageLine."Line Type";
                    LineTypeCode := Format(LineTypeOrdinal, 0, 9);
                    LineTypeName := Format(CoverageLine."Line Type");
                    CoverageStatusOrdinal := CoverageLine."Code Coverage Status";
                    CoverageStatusCode := Format(CoverageStatusOrdinal, 0, 9);
                    CoverageStatusName := Format(CoverageLine."Code Coverage Status");
                end;
            }
        }
    }

    trigger OnPreXmlPort()
    begin
        SchemaVersion := RawXmlSchemaVersionLbl;
    end;

    var
        RawXmlSchemaVersionLbl: Label '1', Locked = true;
}
