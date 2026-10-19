using System;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace CarBud_Proto1
{
    // Browse and filter the cars
    public partial class Cars : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                // Fill the "Type" drop-down from the database
                ddlType.DataSource = CarManager.GetCarTypes();
                ddlType.DataTextField = "CarType";
                ddlType.DataValueField = "CarType";
                ddlType.DataBind();
                ddlType.Items.Insert(0, new ListItem("All types", ""));

                LoadCars();
            }
        }

        protected void btnFilter_Click(object sender, EventArgs e)
        {
            LoadCars();
        }

        private void LoadCars()
        {
            string carType = ddlType.SelectedValue == "" ? null : ddlType.SelectedValue;
            int? maxPrice = NumberOrNull(ddlPrice.SelectedValue);
            int? minSeats = NumberOrNull(ddlSeats.SelectedValue);

            DataTable cars = CarManager.SearchCars(carType, maxPrice, minSeats);

            rptCars.DataSource = cars;
            rptCars.DataBind();

            pnlEmpty.Visible = cars.Rows.Count == 0;
            litCount.Text = cars.Rows.Count == 1 ? "1 car" : cars.Rows.Count + " cars";
        }

        // "" becomes null (no filter), "700" becomes 700
        private static int? NumberOrNull(string value)
        {
            int number;
            if (int.TryParse(value, out number))
            {
                return number;
            }
            return null;
        }
    }
}
