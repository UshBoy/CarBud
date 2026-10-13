using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace CarBud_Proto1
{
    public partial class TestCars : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                gvCars.DataSource = CarManager.GetAllCars();
                gvCars.DataBind();
            }
        }
    }
}