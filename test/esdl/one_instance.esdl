<?xml version='1.0' encoding='UTF-8'?>
<!--An ESDL file with a single instance named "Main", containing 5 + (3) = 8 assets.-->
<esdl:EnergySystem xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:esdl="http://www.tno.nl/esdl" name="Norse Mythology" id="d4643afe-3813-4981-8fcf-974ca7018b5b" description="" esdlVersion="v2303" version="6">
  <instance xsi:type="esdl:Instance" id="ad7d4261-f4f7-4c63-8935-8e26ebf09b2f" name="Main">
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
      <asset xsi:type="esdl:FuelCell" name="FuelCell_9121" id="91218656-3706-403a-909c-f67d14f8b40c">
        <geometry xsi:type="esdl:Point" lat="64.20667602226591" lon="-20.916252136230472"/>
        <port xsi:type="esdl:InPort" connectedTo="8a8f5c5c-3556-4a51-81db-0f2f74eb8dc0" name="In" id="27e984b8-7414-46c7-9f73-5f089a3c7719"/>
        <port xsi:type="esdl:OutPort" name="E Out" connectedTo="5e71413e-6c3c-491f-9aef-f7702dffc477" id="a02d8cc6-ea45-4bfe-91c0-1813995c5f34"/>
        <port xsi:type="esdl:OutPort" name="H Out" connectedTo="08332a70-84ef-43bb-8619-a1805dd8a52f" id="33e09eff-3a6f-4ba0-aa52-7d3595aef6f8"/>
      </asset>
      <area xsi:type="esdl:Area" id="dd27f13b-6d1e-4532-9092-bf5240099570" name="Valhalla">
        <asset xsi:type="esdl:PVInstallation" name="PVInstallation_e36d" id="e36d17db-241b-4385-b479-b5e62eae095d">
          <geometry xsi:type="esdl:Point" lat="64.28737746326682" lon="-21.061477661132816"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="efd5ad97-7b65-4acc-8bfc-44fb181daa84 f937380b-3ab1-4e57-b30d-65d90f5b2d4d" id="9bd4851c-7b05-46eb-ae42-21eccc3b17f9"/>
        </asset>
        <asset xsi:type="esdl:ElectricityDemand" name="ElectricityDemand_928f" id="928f1a33-549d-4e45-86aa-bb2258458a67">
          <geometry xsi:type="esdl:Point" lat="64.26815581064805" lon="-21.054267883300785"/>
          <port xsi:type="esdl:InPort" connectedTo="b7b65117-a9fd-4fe9-934d-1626a9939cfe 9bd4851c-7b05-46eb-ae42-21eccc3b17f9" name="In" id="efd5ad97-7b65-4acc-8bfc-44fb181daa84"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="4d8e6f38-6ea6-41ea-a08b-25394cb0ed96 5e71413e-6c3c-491f-9aef-f7702dffc477 f937380b-3ab1-4e57-b30d-65d90f5b2d4d" id="eff6f16f-5544-4889-b51a-829a09acba13"/>
        </asset>
        <asset xsi:type="esdl:PowerPlant" type="COMBINED_CYCLE_GAS_TURBINE" name="PowerPlant_4e99" id="4e9941cd-3e92-4b52-bc66-5ca5e50ec16a">
          <geometry xsi:type="esdl:Point" lat="64.26547265526776" lon="-21.087913513183597"/>
          <port xsi:type="esdl:InPort" connectedTo="eeace68b-c6b6-498b-9980-356b6243e122" name="In" id="9b1b3014-be88-4e51-85d7-479a6ed2a42c"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="efd5ad97-7b65-4acc-8bfc-44fb181daa84" id="b7b65117-a9fd-4fe9-934d-1626a9939cfe"/>
        </asset>
      </area>
    </area>
  </instance>
</esdl:EnergySystem>
