<?xml version='1.0' encoding='UTF-8'?>
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
        <asset xsi:type="esdl:FuelCell" name="FuelCell_9121" id="91218656-3706-403a-909c-f67d14f8b40c">
          <geometry xsi:type="esdl:Point" lat="64.20667602226591" lon="-20.916252136230472"/>
          <port xsi:type="esdl:InPort" connectedTo="8a8f5c5c-3556-4a51-81db-0f2f74eb8dc0" name="In" id="27e984b8-7414-46c7-9f73-5f089a3c7719"/>
          <port xsi:type="esdl:OutPort" name="E Out" connectedTo="5e71413e-6c3c-491f-9aef-f7702dffc477" id="a02d8cc6-ea45-4bfe-91c0-1813995c5f34"/>
          <port xsi:type="esdl:OutPort" name="H Out" connectedTo="08332a70-84ef-43bb-8619-a1805dd8a52f" id="33e09eff-3a6f-4ba0-aa52-7d3595aef6f8"/>
        </asset>
        <asset xsi:type="esdl:PowerPlant" type="COMBINED_CYCLE_GAS_TURBINE" name="PowerPlant_7227" id="7227d20f-918c-4de1-b698-a40ba29e9bc7">
          <geometry xsi:type="esdl:Point" lat="64.22862745817535" lon="-20.965690612792972"/>
          <port xsi:type="esdl:InPort" connectedTo="eeace68b-c6b6-498b-9980-356b6243e122" name="In" id="ec622226-8d89-4464-8147-c7eafea89ca5"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="5e71413e-6c3c-491f-9aef-f7702dffc477" id="c0ad56e3-3a83-46e9-8d2e-43cbd02e08c9"/>
        </asset>
        <asset xsi:type="esdl:ElectricityNetwork" name="ElectricityNetwork_be51" id="be51458b-218f-46cb-af0b-315fc879b0f0">
          <geometry xsi:type="esdl:Point" lat="64.23429914733688" lon="-20.932731628417972"/>
          <port xsi:type="esdl:InPort" connectedTo="a02d8cc6-ea45-4bfe-91c0-1813995c5f34 c0ad56e3-3a83-46e9-8d2e-43cbd02e08c9 eff6f16f-5544-4889-b51a-829a09acba13 089d1dfa-abfd-4314-a9f7-e905697a19e0" name="In" id="5e71413e-6c3c-491f-9aef-f7702dffc477"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="29ce99fd-0c4f-47ae-8e29-ab6c4041a400 a439cb30-d40f-498b-b6a7-e0cfcbda0752 2f90ec2a-9efc-4979-9d86-99202db07c29" id="dc76a962-0359-4f88-9774-054c81aa78f2"/>
        </asset>
        <asset xsi:type="esdl:GasDemand" name="Hydrogen demand" id="45fa1a43-8943-4d8f-8eba-bafbae17f974">
          <geometry xsi:type="esdl:Point" lat="64.21055985664894" lon="-20.97770690917969"/>
          <port xsi:type="esdl:InPort" connectedTo="832a041e-8e71-46bc-8945-69705d87ba0a f4e1f65a-98bd-482c-8fd1-56cd70d4b515" name="In" id="509306f7-dd17-4597-8166-b7f8fa8854d0"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="584e6bd3-36ac-4540-b7d1-c6280785b9b9 27e984b8-7414-46c7-9f73-5f089a3c7719" id="8a8f5c5c-3556-4a51-81db-0f2f74eb8dc0"/>
        </asset>
        <asset xsi:type="esdl:GasConversion" name="Hydrogen generator" id="05058aad-f87e-4207-9118-e005a62a4004">
          <geometry xsi:type="esdl:Point" lat="64.20772172357896" lon="-21.01341247558594"/>
          <port xsi:type="esdl:InPort" connectedTo="eeace68b-c6b6-498b-9980-356b6243e122" name="In" id="2582d2d0-24b7-4e82-a2df-d192cfe55fbe"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="509306f7-dd17-4597-8166-b7f8fa8854d0" id="832a041e-8e71-46bc-8945-69705d87ba0a"/>
        </asset>
        <asset xsi:type="esdl:HeatProducer" name="Waste heat" id="f1b99314-4b7c-4f6b-88f2-520f4617fcf6">
          <geometry xsi:type="esdl:Point" lat="64.22982159465025" lon="-20.857200622558597"/>
          <port xsi:type="esdl:OutPort" name="Out" connectedTo="82d42ef9-7d32-4991-821c-62b03a751ccf" id="db89cb60-8609-4417-bdbe-a7704a734176"/>
        </asset>
        <asset xsi:type="esdl:HeatingDemand" name="HeatingDemand_d3b9" id="d3b98f6d-abda-4f10-98fc-f9d86f77fbe4">
          <geometry xsi:type="esdl:Point" lat="64.20518209473963" lon="-20.864067077636722"/>
          <port xsi:type="esdl:InPort" connectedTo="bb1b80cd-bce7-467d-8e86-b8b0e8644ee6 33e09eff-3a6f-4ba0-aa52-7d3595aef6f8" name="In" id="08332a70-84ef-43bb-8619-a1805dd8a52f"/>
        </asset>
      </area>
    </area>
  </instance>
</esdl:EnergySystem>
