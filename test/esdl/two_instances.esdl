<?xml version='1.0' encoding='UTF-8'?>
<!--An ESDL file with two instances -->
<!--The first instance is named "Flat" has 4 assets directly under the first area-->
<!--The second instance is named "Nested" has nested areas containing (4) + (6) = 10 assets-->
<esdl:EnergySystem xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:esdl="http://www.tno.nl/esdl" name="Norse Mythology" id="d4643afe-3813-4981-8fcf-974ca7018b5b" description="" esdlVersion="v2303" version="6">
  <instance xsi:type="esdl:Instance" id="ad7d4261-f4f7-4c63-8935-8e26ebf09b2f" name="Flat">
    <area xsi:type="esdl:Area" id="83dfdeaf-f885-462a-ac24-d3d3118c8f15" name="Iceland">
      <asset xsi:type="esdl:Export" name="Export_06ca" id="06ca24ec-77f5-44fe-be5a-bf2a059e8654">
        <geometry xsi:type="esdl:Point" lat="64.23429914733688" lon="-20.901145935058597"/>
        <port xsi:type="esdl:InPort" connectedTo="dc76a962-0359-4f88-9774-054c81aa78f2" name="In" id="29ce99fd-0c4f-47ae-8e29-ab6c4041a400"/>
      </asset>
      <asset xsi:type="esdl:Electrolyzer" name="Electrolyzer_41ac" id="41ac619a-f1c5-4d89-a6f7-e75a9783c189">
        <geometry xsi:type="esdl:Point" lat="64.2198191095311" lon="-20.953330993652347"/>
        <port xsi:type="esdl:InPort" connectedTo="dc76a962-0359-4f88-9774-054c81aa78f2 f4e1f65a-98bd-482c-8fd1-56cd70d4b515" name="In" id="a439cb30-d40f-498b-b6a7-e0cfcbda0752"/>
        <port xsi:type="esdl:OutPort" name="Out" connectedTo="a439cb30-d40f-498b-b6a7-e0cfcbda0752 509306f7-dd17-4597-8166-b7f8fa8854d0" id="f4e1f65a-98bd-482c-8fd1-56cd70d4b515"/>
      </asset>
      <asset xsi:type="esdl:GasStorage" name="GasStorage_f713" id="f7138a43-41d8-4fa7-9504-ed340bc5205e">
        <geometry xsi:type="esdl:Point" lat="64.21683259218487" lon="-20.99349975585938"/>
        <port xsi:type="esdl:InPort" connectedTo="8a8f5c5c-3556-4a51-81db-0f2f74eb8dc0" name="In" id="584e6bd3-36ac-4540-b7d1-c6280785b9b9"/>
      </asset>
      <asset xsi:type="esdl:HeatPump" name="HeatPump_4b33" id="4b33f488-b157-411a-ab02-7a0d43c154a3">
        <geometry xsi:type="esdl:Point" lat="64.22728399302186" lon="-20.88912963867188"/>
        <port xsi:type="esdl:InPort" connectedTo="dc76a962-0359-4f88-9774-054c81aa78f2" name="In" id="2f90ec2a-9efc-4979-9d86-99202db07c29"/>
        <port xsi:type="esdl:OutPort" name="Out" connectedTo="08332a70-84ef-43bb-8619-a1805dd8a52f" id="bb1b80cd-bce7-467d-8e86-b8b0e8644ee6"/>
        <port xsi:type="esdl:InPort" connectedTo="db89cb60-8609-4417-bdbe-a7704a734176" name="Waste heat inport" id="82d42ef9-7d32-4991-821c-62b03a751ccf"/>
      </asset>
    </area>
  </instance>
  <instance xsi:type="esdl:Instance" id="ad7d4261-f4f7-4c63-8935-8e26ebf09b2f" name="Nested">
    <area xsi:type="esdl:Area" id="83dfdeaf-f885-462a-ac24-d3d3118c8f15" name="Iceland">
      <area xsi:type="esdl:Area" id="3c9f292f-d7a8-4f0b-b5a8-0b17dc6ca49e" name="Asgard">
        <asset xsi:type="esdl:Export" name="Export_06ca" id="06ca24ec-77f5-44fe-be5a-bf2a059e8654">
          <geometry xsi:type="esdl:Point" lat="64.23429914733688" lon="-20.901145935058597"/>
          <port xsi:type="esdl:InPort" connectedTo="dc76a962-0359-4f88-9774-054c81aa78f2" name="In" id="29ce99fd-0c4f-47ae-8e29-ab6c4041a400"/>
        </asset>
        <asset xsi:type="esdl:Electrolyzer" name="Electrolyzer_41ac" id="41ac619a-f1c5-4d89-a6f7-e75a9783c189">
          <geometry xsi:type="esdl:Point" lat="64.2198191095311" lon="-20.953330993652347"/>
          <port xsi:type="esdl:InPort" connectedTo="dc76a962-0359-4f88-9774-054c81aa78f2 f4e1f65a-98bd-482c-8fd1-56cd70d4b515" name="In" id="a439cb30-d40f-498b-b6a7-e0cfcbda0752"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="a439cb30-d40f-498b-b6a7-e0cfcbda0752 509306f7-dd17-4597-8166-b7f8fa8854d0" id="f4e1f65a-98bd-482c-8fd1-56cd70d4b515"/>
        </asset>
        <asset xsi:type="esdl:GasStorage" name="GasStorage_f713" id="f7138a43-41d8-4fa7-9504-ed340bc5205e">
          <geometry xsi:type="esdl:Point" lat="64.21683259218487" lon="-20.99349975585938"/>
          <port xsi:type="esdl:InPort" connectedTo="8a8f5c5c-3556-4a51-81db-0f2f74eb8dc0" name="In" id="584e6bd3-36ac-4540-b7d1-c6280785b9b9"/>
        </asset>
        <asset xsi:type="esdl:HeatPump" name="HeatPump_4b33" id="4b33f488-b157-411a-ab02-7a0d43c154a3">
          <geometry xsi:type="esdl:Point" lat="64.22728399302186" lon="-20.88912963867188"/>
          <port xsi:type="esdl:InPort" connectedTo="dc76a962-0359-4f88-9774-054c81aa78f2" name="In" id="2f90ec2a-9efc-4979-9d86-99202db07c29"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="08332a70-84ef-43bb-8619-a1805dd8a52f" id="bb1b80cd-bce7-467d-8e86-b8b0e8644ee6"/>
          <port xsi:type="esdl:InPort" connectedTo="db89cb60-8609-4417-bdbe-a7704a734176" name="Waste heat inport" id="82d42ef9-7d32-4991-821c-62b03a751ccf"/>
        </asset>
      </area>
      <area xsi:type="esdl:Area" id="befa140e-ae38-4ac9-97c5-09376be5bbad" name="Midgard">
        <geometry xsi:type="esdl:Polygon" CRS="WGS84">
          <exterior xsi:type="esdl:SubPolygon">
            <point xsi:type="esdl:Point" lat="64.26905013784292" lon="-20.931015014648438"/>
            <point xsi:type="esdl:Point" lat="64.29690882007257" lon="-20.946121215820316"/>
            <point xsi:type="esdl:Point" lat="64.30941372865048" lon="-20.85617065429688"/>
            <point xsi:type="esdl:Point" lat="64.29854669036891" lon="-20.78922271728516"/>
            <point xsi:type="esdl:Point" lat="64.26636706936117" lon="-20.80020904541016"/>
          </exterior>
        </geometry>
        <asset xsi:type="esdl:WindTurbine" name="WindTurbine_6cb4" id="6cb408e6-ab0c-4d1e-91e8-497a9c1bb21c">
          <geometry xsi:type="esdl:Point" lat="64.294526289623" lon="-20.895996093750004"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="4d8e6f38-6ea6-41ea-a08b-25394cb0ed96" id="78aa04bd-6e64-40f3-86b2-bab87cf3936e"/>
        </asset>
        <asset xsi:type="esdl:Import" name="Import_56bb" id="56bba6e3-29ae-4b22-9005-111d03d240db">
          <geometry xsi:type="esdl:Point" lat="64.28231259027915" lon="-20.863037109375004"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="4d8e6f38-6ea6-41ea-a08b-25394cb0ed96" id="6a09f018-deea-49c1-94dc-557a5afec0c4"/>
        </asset>
        <asset xsi:type="esdl:PumpedHydroPower" name="PumpedHydroPower_eabf" id="eabff8a3-a0bc-42da-a9c4-4d094cf2391a">
          <geometry xsi:type="esdl:Point" lat="64.29363278764076" lon="-20.92552185058594"/>
          <port xsi:type="esdl:InPort" connectedTo="089d1dfa-abfd-4314-a9f7-e905697a19e0" name="In" id="58194ed4-51ea-4086-abef-e804d11a98c1"/>
        </asset>
        <asset xsi:type="esdl:ElectricityDemand" name="ElectricityDemand_1e9e" id="1e9ec4ee-e457-4c3c-9957-a4700498bb46">
          <geometry xsi:type="esdl:Point" lat="64.27754480168016" lon="-20.899085998535156"/>
          <port xsi:type="esdl:InPort" connectedTo="78aa04bd-6e64-40f3-86b2-bab87cf3936e f0433555-3e3c-4650-83fb-1bdb8e291e86 e2593ac4-78be-431d-b420-1207d7d67ca1 6a09f018-deea-49c1-94dc-557a5afec0c4 eff6f16f-5544-4889-b51a-829a09acba13" name="In" id="4d8e6f38-6ea6-41ea-a08b-25394cb0ed96"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="58194ed4-51ea-4086-abef-e804d11a98c1 5e71413e-6c3c-491f-9aef-f7702dffc477" id="089d1dfa-abfd-4314-a9f7-e905697a19e0"/>
        </asset>
        <asset xsi:type="esdl:PowerPlant" type="COMBINED_CYCLE_GAS_TURBINE" name="PowerPlant_2d4c" id="2d4c5a85-6765-4c54-9de6-8722256976ff">
          <geometry xsi:type="esdl:Point" lat="64.2781408202984" lon="-20.852737426757816"/>
          <port xsi:type="esdl:InPort" connectedTo="eeace68b-c6b6-498b-9980-356b6243e122" name="In" id="d720f1c2-04d0-4bd6-b9a5-1fbe8d151427"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="4d8e6f38-6ea6-41ea-a08b-25394cb0ed96" id="f0433555-3e3c-4650-83fb-1bdb8e291e86"/>
        </asset>
        <asset xsi:type="esdl:PowerPlant" type="NUCLEAR_3RD_GENERATION" name="PowerPlant_4e1c" id="4e1cd004-da90-4135-8399-fb8c56dbdcb3">
          <geometry xsi:type="esdl:Point" lat="64.2918456968408" lon="-20.87608337402344" CRS="WGS84"/>
          <port xsi:type="esdl:InPort" name="In" id="776a35a4-ef22-40a0-b488-94815b1b201a"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="4d8e6f38-6ea6-41ea-a08b-25394cb0ed96" id="e2593ac4-78be-431d-b420-1207d7d67ca1"/>
        </asset>
      </area>
    </area>
  </instance>
</esdl:EnergySystem>
